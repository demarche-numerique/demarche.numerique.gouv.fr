# frozen_string_literal: true

module Users
  module DossiersPersonnalisation
    class DemarcheCardComponent < ApplicationComponent
      def initialize(procedure:, presentation:)
        @procedure = procedure
        @presentation = presentation
      end

      attr_reader :procedure, :presentation

      def empty?
        presentation.displayed_columns.blank?
      end

      def react_props
        {
          id: "personnalisation-combobox-#{procedure.id}",
          name: "presentations[#{procedure.id}][displayed_column_ids][]",
          items: items_for_combobox,
          selected_keys: selected_stable_ids,
          placeholder: t('users.dossiers_personnalisation.edit.combobox_placeholder'),
          tags_below: true,
          value_separator: false,
        }
      end

      private

      def items_for_combobox
        types_de_champ.map { |tdc| [label_for(tdc), tdc.stable_id.to_s] }
      end

      def types_de_champ
        @types_de_champ ||= procedure.types_de_champ_personnalisables.to_a
      end

      def label_for(tdc)
        tdc.mandatory? ? "#{tdc.libelle} *" : tdc.libelle
      end

      def selected_stable_ids
        Array(presentation.displayed_columns).map { |c| c.stable_id.to_s }
      end
    end
  end
end
