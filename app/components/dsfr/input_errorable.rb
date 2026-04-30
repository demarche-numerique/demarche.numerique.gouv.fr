# frozen_string_literal: true

module Dsfr
  module InputErrorable
    extend ActiveSupport::Concern
    include ChampAriaLabelledbyHelper

    included do
      delegate :object, to: :@form
      delegate :errors, to: :object

      renders_one :hint

      def dsfr_group_classname
        if dsfr_champ_container == :fieldset
          'fr-fieldset'
        elsif dsfr_input_classname.present? # non fillable element
          "#{dsfr_input_classname}-group"
        end
      end

      def input_group_error_class_names
        return {} if dsfr_group_classname.nil?

        {
          "#{dsfr_group_classname}--error" => errors_on_attribute?,
          "#{dsfr_group_classname}--valid" => !errors_on_attribute? && errors_on_another_attribute? && object.try(attribute).present?,
        }
      end

      def errors_on_attribute?
        # When the object is a Champ, errors can be stored as nested errors on the dossier
        # or directly on the champ object
        if object.is_a?(Champ)
          dossier_errors_for_champ.any? || errors.any?
        else
          errors.has_key?(attribute_or_rich_body)
        end
      end

      # errors helpers
      def error_full_messages
        # When the object is a Champ, errors can be stored as nested errors on the dossier
        # because validation adds errors to champ instances that may differ from the form object
        # or directly on the champ object
        if object.is_a?(Champ)
          (dossier_errors_for_champ + errors.full_messages).uniq
        else
          errors.full_messages_for(attribute_or_rich_body)
        end
      end

      def fieldset_error_opts
        if dsfr_champ_container == :fieldset && errors_on_attribute?
          labelledby = [input_label_id(@champ)]
          labelledby << describedby_id if @champ.description.present?
          labelledby << @champ.error_id(@attribute)

          {
            aria: { labelledby: labelledby.join(' ') },
          }
        else
          {}
        end
      end

      def default_hint
        if I18n.exists?("activerecord.attributes.#{object.class.name.underscore}.hints.#{@attribute}")
          I18n.t("activerecord.attributes.#{object.class.name.underscore}.hints.#{@attribute}", application_name: APPLICATION_NAME)
        elsif I18n.exists?("activerecord.attributes.#{object.class.name.underscore}.hints.#{@attribute}_html")
          I18n.t("activerecord.attributes.#{object.class.name.underscore}.hints.#{@attribute}_html", application_name: APPLICATION_NAME).html_safe
        end
      end

      private

      def dossier_errors_for_champ
        object.dossier.errors
          .filter do |error|
            # Match nested errors where the champ public_id matches this champ's public_id
            error.is_a?(ActiveModel::NestedError) &&
            error.inner_error.base.respond_to?(:public_id) &&
            error.inner_error.base.public_id == object.public_id
          end.map(&:message)
      end

      # lookup for edge case from `form.rich_text_area`
      #   rich text uses _rich_#{attribute}, but it is saved on #{attribute}, as well as error messages
      def attribute_or_rich_body
        case @input_type
        when :rich_text_area
          attribute.to_s.sub(/\Arich_/, '').to_sym
        else
          attribute
        end
      end

      def fr_fieldset?
        !['fr-input', 'fr-radio', 'fr-select'].include?(dsfr_input_classname)
      end

      def input_error_class_names
        {
          "#{dsfr_input_classname}--error": errors_on_attribute?,
        }
      end

      def react_input_opts(other_opts = {})
        input_opts(other_opts, true).compact
      end

      def input_opts(other_opts = {}, react = false)
        @opts = @opts.deep_merge!(other_opts)
        @opts[react ? :class_name : :class] = class_names(map_array_to_hash_with_true(@opts[:class])
                                      .merge({
                                        'fr-password__input': password?,
                                             'fr-input': !react,
                                             'fr-mb-0': true,
                                      }.merge(input_error_class_names)))

        aria_describedby = []

        if object.respond_to?(:description) && object.description.present?
          aria_describedby << describedby_id
        elsif hintable?
          aria_describedby << hint_id
        end

        aria_describedby << object.error_id(attribute) if errors_on_attribute? && object.respond_to?(:error_id)

        @opts.deep_merge!('aria-describedby': aria_describedby.join(' ')) if aria_describedby.present?

        if @required
          @opts[react ? :is_required : :required] = true
        end

        if email?
          @opts.deep_merge!(data: {
            action: "blur->email-input#checkEmail",
            'email-input-target': 'input',
          })
        end

        @opts.deep_merge!(data: { controller: token_list(@opts.dig(:data, :controller), 'autoresize' => autoresize?) })

        @opts
      end

      def errors_on_another_attribute?
        !errors.empty?
      end

      def map_array_to_hash_with_true(array_or_string_or_nil)
        Array(array_or_string_or_nil).index_with { true }
      end

      # Replaces `hint?` because view_component considers that
      # having `default_hint` method means we always render a hint,
      # which is not true.
      def hint_renderable? = hint&.content?

      def password?
        false
      end

      def email?
        false
      end

      def autoresize?
        false
      end

      def hintable?
        false
      end
    end
  end
end
