# frozen_string_literal: true

Rails.application.config.active_storage.service_urls_expire_in = 1.hour

Rails.application.config.active_storage.variant_processor = :vips

# Disable automatic blob analysis - we don't use the extracted metadata
# (dimensions, duration, etc.) and it generates unnecessary AnalyzeJob executions
Rails.application.config.active_storage.analyzers = []

# Per-procedure storage service selection.
#
# When the `s3_storage` feature flag is enabled on a procedure, new blobs are
# created on the :amazon (S3) service instead of the default one. The choice has
# to happen at blob *creation* (direct upload): attaching an already-created blob
# never reconsiders its service.
#
# Callers (web `DirectUploadsController`, GraphQL `CreateDirectUpload`) pass the
# `procedure_id`; the flag is the single source of truth and `ProcedureFlipperActor`
# checks it without loading the procedure.
module ActiveStorageBlobServicePerProcedure
  def create_before_direct_upload!(procedure_id: nil, service_name: nil, **args)
    if service_name.nil? && procedure_id.present? && Flipper.enabled?(:s3_storage, ProcedureFlipperActor.new(procedure_id))
      service_name = :amazon
    end

    super(service_name:, **args)
  end
end

ActiveSupport.on_load(:active_storage_blob) do
  singleton_class.prepend(ActiveStorageBlobServicePerProcedure)
end

ActiveSupport.on_load(:active_storage_blob) do
  include BlobProcessorConcern
  include BlobVirusScannerConcern
  include BlobSignedIdConcern

  # With analyzers disabled, ActiveStorage falls back to NullAnalyzer whose
  # `analyze_later? == false`, so `analyze_blob_later` (after_create_commit on
  # Attachment) ends up calling `blob.update! metadata: ...` synchronously.
  # Under contention (e.g. a batch op where N workers attach the same blob),
  # those UPDATEs serialize on the same row and hit PG statement_timeout.
  # Pre-marking the blob as analyzed at INSERT time short-circuits the
  # `unless blob.analyzed?` guard in `Attachment#analyze_blob_later`, so no
  # extra UPDATE is ever issued.
  before_create do
    self.metadata = metadata.merge("analyzed" => true)
  end

  # Marcel maps legacy JPEG extensions (.jfif/.jfi/.jif/.jpe — emitted by older
  # Outlook/Edge/Office builds) to image/jpeg, but libvips has no saver for them
  # so variants fail at write time. We rewrite the filename to .jpg at upload:
  # the file content is bit-for-bit a JPEG already, only the extension is
  # legacy. Also makes the downloaded original portable on Windows/Office where
  # those extensions are still poorly supported.
  before_create do
    if content_type == "image/jpeg" && filename.extension.to_s.downcase.in?(%w[jfif jfi jif jpe])
      self.filename = "#{filename.base}.jpg"
    end
  end

  # Direct upload is the one path that stores the content type declared by the
  # client without ever reading the file, and `identified` stays false until
  # something does. Building a variant from such a blob means deciding it is an
  # image on the uploader's word alone, so refuse: the image library picks its
  # decoder from the bytes and will not agree with a type nobody checked.
  def variable?
    identified? && super
  end

  # Same for previews: the previewer is picked from the declared content type
  # too, and it hands the bytes to pdftoppm or ffmpeg rather than to the image
  # library. `representation` tries this before `variant`, so guarding only the
  # latter would leave the wider decoder open.
  def previewable?
    identified? && super
  end

  # Rails identifies blobs with Marcel, matching the first bytes against a
  # dictionary of magic signatures. When no signature matches, it falls back to
  # the filename extension to guess the MIME type, which is dangerous. We only
  # want to build variants for files whose magic bytes are recognized, so we
  # return the binary MIME type for anything unknown.
  private def identify_content_type
    chunk = download_identifiable_chunk
    declared = Marcel::MimeType.for(chunk, name: filename.to_s, declared_type: content_type)

    if declared.in?(ActiveStorage.variable_content_types)
      magic = Marcel::MimeType.for(chunk)

      if magic != declared
        Sentry.capture_message(
          "Suspicious attachment: declared variable content type not confirmed by magic bytes",
          level: :warning,
          extra: {
            blob_id: id,
            filename: filename.to_s,
            declared_type: declared,
            magic_type: magic,
            head_hex: chunk.byteslice(0, 32).unpack1("H*"),
          }
        )
        declared = Marcel::MimeType::BINARY
      end
    end

    declared
  end

  ActiveStorage::Blob.class_eval do
    def purge_later
      DelayedPurgeJob.perform_later(self)
    end
  end

  def self.generate_unique_secure_token(length: MINIMUM_TOKEN_LENGTH)
    token = super
    "#{Time.current.strftime('%Y/%m/%d')}/#{token[0..1]}/#{token}"
  end
end

ActiveSupport.on_load(:active_storage_attachment) do
  include AttachmentProcessorConcern
end

# Forward the `procedure_id` (sent by the web direct upload URL) down to
# `create_before_direct_upload!` so it can pick the storage service.
module DirectUploadsProcedureScope
  private

  def blob_args
    super.merge(procedure_id: params[:procedure_id])
  end
end

Rails.application.reloader.to_prepare do
  ActiveStorage::DirectUploadsController.prepend(DirectUploadsProcedureScope)
end

Rails.application.reloader.to_prepare do
  class ActiveStorage::BaseJob
    include ActiveJob::RetryOnStandardError
  end

  class ActiveStorage::BaseController
    # same store as ApplicationController
    protect_from_forgery with: :exception, store: :cookie
  end

  # A blob we decline to transform is a missing representation, not a server
  # error: the signed id and the variation key are both valid, they just do not
  # compose into something we are willing to render.
  class ActiveStorage::Representations::BaseController
    rescue_from ActiveStorage::UnrepresentableError, ActiveStorage::InvariableError do
      head :not_found
    end
  end
end

# When an OpenStack service is initialized it makes a request to fetch
# `publicURL` to use for all operations. We intercept the method that reads
# this url and replace the host with DS_Proxy host. This way all the operation
# are performed through DS_Proxy.
#
# https://github.com/fog/fog-openstack/blob/37621bb1d5ca78d037b3c56bd307f93bba022ae1/lib/fog/openstack/auth/catalog/v2.rb#L16
require 'fog/openstack/auth/catalog/v2'

module Fog::OpenStack::Auth::Catalog
  class V2
    def endpoint_url(endpoint, interface)
      url = endpoint["#{interface}URL"]

      if interface == 'public'
        publicize(url)
      else
        url
      end
    end

    private

    def publicize(url)
      search = %r{^https://[^/]+/}
      replace = "#{ENV['DS_PROXY_URL']}/"
      url.gsub(search, replace)
    end
  end
end

require 'fog/openstack/auth/catalog/v3'
module Fog::OpenStack::Auth::Catalog
  class V3
    def endpoint_url(endpoint, interface)
      url = endpoint["url"]

      if interface == 'public'
        publicize(url)
      else
        url
      end
    end

    private

    def publicize(url)
      search = %r{^https://[^/]+/}
      replace = "#{ENV['DS_PROXY_URL']}/"
      url.gsub(search, replace)
    end
  end
end

# fog-openstack 1.1.x builds the bulk-delete request body with `URI.encode`, which
# Ruby removed in 3.0, so `delete_multiple_objects` raises NoMethodError on any
# non-empty object list. `URI::DEFAULT_PARSER.escape` is the drop-in replacement:
# same escaping rules, and it keeps the `container/object` slash literal (unlike
# `ERB::Util.url_encode`, which would encode it and break the path).
#
# We PREPEND a module rather than reopen the class: fog requires the original request
# file lazily, on the first `Fog::OpenStack::Storage.new` (setup_requirements ->
# require_requests_and_mock), which happens AFTER this initializer. A class reopen
# would then be redefined (clobbered) by that require; a prepended module stays ahead
# of Real in the ancestor chain and wins whatever the load order.
#
# https://github.com/fog/fog-openstack/blob/v1.1.5/lib/fog/openstack/storage/requests/delete_multiple_objects.rb
require 'fog/openstack'

module OpenStackBulkDeletePatch
  def delete_multiple_objects(container, object_names, options = {})
    body = object_names.map do |name|
      object_name = container ? "#{container}/#{name}" : name
      URI::DEFAULT_PARSER.escape(object_name)
    end.join("\n")

    response = request({
      expects: 200,
      method: 'DELETE',
      headers: options.merge('Content-Type' => 'text/plain', 'Accept' => 'application/json'),
      body:,
      query: { 'bulk-delete' => true },
    }, false)
    response.body = Fog::JSON.decode(response.body)
    response
  end
end

Fog::OpenStack::Storage::Real.prepend(OpenStackBulkDeletePatch)

# `activestorage-openstack` serves a byte range by downloading the WHOLE object and
# slicing it in Ruby (`chunk_buffer.join[range]`), because fog-openstack's `get_object`
# takes neither options nor headers. Add a request that does, so the service asks the
# storage for the bytes it wants — the way Rails' own S3 service does.
#
# PREPENDED like the bulk-delete patch above: fog requires its request files lazily,
# after this initializer has run.
require 'active_storage/service/open_stack_service'

module OpenStackRangeRequestPatch
  # A response block, like `get_object`: without one, `Fog::OpenStack::Core#request`
  # calls `.match` on a Content-Type the response may not carry.
  def get_object_range(container, object, first, last, &block)
    request({
      # NOT 416: Excon only feeds the response block for an expected status, so accepting
      # it would hand back the storage's error page as the file's first bytes.
      expects: [200, 206],
      method: 'GET',
      path: "#{Fog::OpenStack.escape(container)}/#{Fog::OpenStack.escape(object)}",
      headers: { 'Range' => "bytes=#{first}-#{last}" },
      response_block: block,
    }, false)
  end
end

Fog::OpenStack::Storage::Real.prepend(OpenStackRangeRequestPatch)

module OpenStackRangeDownloadChunkPatch
  def download_chunk(key, range)
    instrument :download_chunk, key: key, range: range do
      first = range.begin
      last = range.exclude_end? ? range.end - 1 : range.end

      # Binary, like the Disk and S3 services: a slice can land inside a multibyte character.
      buffer = +''.b
      response = client.get_object_range(container, key, first, last) { |chunk, *| buffer << chunk.b }

      # A 206 body already starts at `first`; a 200 means the range was not applied.
      offset = response.status == 206 ? 0 : first

      buffer.byteslice(offset, last - first + 1) || ''
    rescue Fog::OpenStack::Storage::NotFound
      raise ActiveStorage::FileNotFoundError
    end
  end
end

ActiveStorage::Service::OpenStackService.prepend(OpenStackRangeDownloadChunkPatch)
