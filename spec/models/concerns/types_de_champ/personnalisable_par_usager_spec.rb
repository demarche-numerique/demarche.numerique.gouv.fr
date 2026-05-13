# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TypesDeChamp::PersonnalisableParUsager do
  describe '.personnalisables_par_usager via Procedure#types_de_champ_personnalisables' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :text, libelle: 'Texte court' },
        { type: :textarea, libelle: 'Texte long' },
        { type: :date, libelle: 'Date' },
        { type: :piece_justificative, libelle: 'PJ' },
        { type: :header_section, libelle: 'Section' },
        { type: :repetition, libelle: 'Bloc', children: [{ type: :text, libelle: 'Sous-champ' }] },
      ])
    end

    subject { procedure.types_de_champ_personnalisables.pluck(:libelle) }

    it do
      is_expected.to include('Texte court', 'Date')
      is_expected.not_to include('Texte long', 'PJ', 'Section', 'Bloc', 'Sous-champ')
    end
  end
end
