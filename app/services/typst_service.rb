# frozen_string_literal: true

require 'open3'

# Renders a Typst template, fed a Typst::Payload, into an accessible
# (PDF/UA-1) PDF with the typst CLI. lib/typst/root holds everything the
# documents may read (templates, logos, fonts) and nothing else. The
# compilation root of a rendering is a temporary directory mirroring it
# through links, plus the files downloaded for that rendering (with_assets):
# typst refuses any path escaping its --root and resolves `..` before
# following a link, so a template cannot reach the rest of the repository.
#
# A template exports a `render(data)` function. The entry document is
# generated here and fed on stdin: it imports the template and decodes the
# JSON payload embedded as a string literal (a large form serialized into
# argv would overflow the kernel's per-argument limit, and argv is visible
# in the host process list). The PDF comes back on stdout.
#
# Typst renders payload strings as literal text, never as markup.
class TypstService
  class Error < StandardError; end

  ROOT = Rails.root.join('lib/typst/root')
  FONTS_DIR = ROOT.join('fonts')
  IMAGES_DIR = ROOT.join('images')
  # Root-relative path of the query helpers, imported into every expression.
  INTROSPECTION_HELPERS = '/introspection.typ'

  # Renders a Typst::Payload with its template, in the compilation root of
  # its assets when it embeds downloaded files.
  def self.render(payload)
    generate_pdf(payload.template, payload.to_h, **{ assets: payload.assets }.compact)
  end

  def self.generate_pdf(template, data, assets: nil)
    run('compile', '--pdf-standard', 'ua-1', '-', '-', assets:, source: entry(template, data), binmode: true, failure: 'PDF generation')
  end

  # Introspects the laid-out document instead of parsing the PDF: evaluates a
  # Typst expression in the context of the rendered template (typst eval --in)
  # and returns its JSON-decoded value. The helpers of
  # lib/typst/root/introspection.typ (headings(), links(), lists(), enums(),
  # tables(), paragraphs(), images(), plain()) are in scope. Used by specs to
  # assert document content.
  def self.query(template, data, expression, assets: nil)
    code = "{\n  import \"#{INTROSPECTION_HELPERS}\": *\n  #{expression}\n}"
    JSON.parse(run('eval', '--in', '-', code, assets:, source: entry(template, data), failure: 'document query'))
  end

  # Letterhead of every document (theme.typ `letterhead`): the instance's
  # bloc-marque and logotype, resolved to compilation-root paths, and the
  # sender lines of the footer. Both images are ENV-configurable (LOGO_SRC,
  # LOGO_MARIANNE_SRC); an empty LOGO_MARIANNE_SRC omits the bloc-marque and
  # the logotype takes its place.
  def self.letterhead
    {
      marianne: LOGO_MARIANNE_SRC.present? ? { path: asset_path(LOGO_MARIANNE_SRC), alt: 'Logo Marianne, République Française' } : nil,
      logo: { path: asset_path(LOGO_SRC), alt: APPLICATION_NAME },
      sender: [DIRECTION_LABEL.presence, APPLICATION_NAME].compact,
    }
  end

  # Files a template embeds beyond its payload (a champ's static map...):
  # Active Storage attachments are downloaded into the compilation root shared
  # by the renders of the block (pass the yielded assets to generate_pdf and
  # query), and the payload references them through the { path:, alt: }
  # descriptors Assets#image returns (theme.typ illustration).
  def self.with_assets
    compilation_root { |root| yield Assets.new(root) }
  end

  class Assets
    attr_reader :root

    def initialize(root)
      @root = root
      @dir = root.join('assets').tap(&:mkpath)
      @count = 0
    end

    # Image descriptor of an attachment (or blob), nil when nothing is
    # attached. A download failure propagates: the caller knows whether the
    # document can do without the image.
    def image(attachment, alt:)
      return if attachment.blank?

      blob = attachment.respond_to?(:blob) ? attachment.blob : attachment
      file = @dir.join("#{@count += 1}#{blob.filename.extension_with_delimiter}")
      file.binwrite(blob.download)

      { path: "/#{file.relative_path_from(root)}", alt: }
    end
  end

  # Root-relative path of an image of lib/typst/root/images (the only images
  # a document can embed besides its assets; the default logos ship there, an
  # instance with its own logos copies them alongside). nil when the file is
  # missing or points outside that directory, in which case the theme renders
  # the alt text in a placeholder frame instead of failing the generation.
  def self.asset_path(src)
    file = IMAGES_DIR.join(src).expand_path
    return if !file.file? || !file.to_s.start_with?("#{IMAGES_DIR}/")

    "/#{file.relative_path_from(ROOT)}"
  end

  # The entry document: a template name is a hardcoded caller constant, the
  # payload is embedded as a Typst string literal (its two escapes, backslash
  # and double quote, are the only ones JSON can contain once script_safe
  # keeps U+2028/2029 out of the source).
  def self.entry(template, data)
    json = JSON.generate(data, script_safe: true).gsub(/["\\]/) { "\\#{it}" }

    "#import \"/#{template}.typ\": render\n#render(json(bytes(\"#{json}\")))\n"
  end

  # A temporary compilation root, gone with the block: every entry of
  # lib/typst/root linked under it. Rendering in a scratch directory rather
  # than in lib/typst/root itself leaves room for the files a rendering may
  # need to add without ever writing into the repository.
  def self.compilation_root
    Dir.mktmpdir('typst', Rails.root.join('tmp')) do |dir|
      root = Pathname(dir)
      ROOT.children.each { File.symlink(it, root.join(it.basename)) }
      yield root
    end
  end

  # The renders of a with_assets block share its compilation root, any other
  # render gets a fresh one.
  def self.in_root(assets, &)
    assets ? yield(assets.root) : compilation_root(&)
  end

  def self.run(command, *args, assets:, source:, failure:, binmode: false)
    in_root(assets) do |root|
      output, diagnostics, status = Open3.capture3(
        'typst', command,
        '--root', root.to_s,
        '--font-path', FONTS_DIR.to_s,
        '--ignore-system-fonts',
        *args,
        stdin_data: source,
        binmode:
      )
      raise Error, "#{failure} failed: #{diagnostics}" unless status.success?

      output
    end
  rescue SystemCallError => e
    # Host-level failures (missing or non-executable typst binary, unwritable
    # tmp/...): surface them under the service's own error class so callers
    # have a single failure contract to handle.
    raise Error, "#{failure} failed: #{e.message}"
  end

  private_class_method :entry, :compilation_root, :in_root, :run
end
