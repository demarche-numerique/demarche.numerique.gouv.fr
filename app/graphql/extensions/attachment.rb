# frozen_string_literal: true

# references:
# https://evilmartians.com/chronicles/active-storage-meets-graphql-pt-2-exposing-attachment-urls

module Extensions
  class Attachment < GraphQL::Schema::FieldExtension
    attr_reader :attachment_assoc, :root

    def apply
      # Here we try to define the ActiveRecord association name:
      # - it could be set explicitly via extension options
      # - or we imply that is the same as the field name w/o "_url"
      # suffix (e.g., "avatar_url" => "avatar")
      @attachment_assoc = if options.key?(:attachment)
        "#{options[:attachment]}_attachment"
      elsif options.key?(:attachments)
        "#{options[:attachments]}_attachments"
      else
        attachment = field.original_name.to_s.sub(/_url$/, "")
        "#{attachment}_attachment"
      end
      @root = options&.dig(:root) || :object
    end

    # This method resolves (as it states) the field itself
    # (it's the same as defining a method within a type)
    def resolve(object:, context:, **_rest)
      root_instance = object.public_send(root)
      # Attachments live on the persisted champ data, not on the projected champ.
      root_instance = root_instance.champ_data if root_instance.is_a?(Champ)
      return if root_instance.nil?

      context.dataloader.with(Sources::Association, attachment_assoc => :blob).load(root_instance)
    end

    # This method is called if the result of the `resolve`
    # is a lazy value (e.g., a Promise – like in our case)
    def after_resolve(value:, **_rest)
      if value.respond_to?(:map)
        attachments = value.map { after_resolve_attachment(_1) }.compact

        if options[:as] == :single
          attachments.first
        else
          attachments
        end
      else
        attachment = after_resolve_attachment(value)
        if options[:as] == :multiple
          [attachment].compact
        else
          attachment
        end
      end
    end

    private

    def after_resolve_attachment(attachment)
      return unless attachment

      if attachment.virus_scanner.safe? || attachment.virus_scanner.pending?
        attachment
      end
    end
  end
end
