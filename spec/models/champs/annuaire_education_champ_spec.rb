# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Champs::AnnuaireEducationChamp do
  describe '#update_external_data!' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :annuaire_education }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.project_champs_public.first.writable!.tap { _1.update_column(:data, 'any data') } }
    subject { champ.send(:update_external_data!, data: data) }

    shared_examples "a data updater (without updating the value)" do |data|
      it do
        expect { subject }.to change { champ.reload.data }.to(data)
        expect { subject }.not_to change { champ.reload.value }
      end
    end

    context 'when data is nil' do
      let(:data) { nil }
      it_behaves_like "a data updater (without updating the value)", nil
    end

    context 'when data is empty' do
      let(:data) { '' }
      it_behaves_like "a data updater (without updating the value)", ''
    end

    context 'when data is consistent' do
      let(:data) {
        {
          'nom_etablissement' => "karrigel an ankou",
          'nom_commune' => 'kumun',
          'identifiant_de_l_etablissement' => '666667',
        }
      }
      it_behaves_like "a data updater (without updating the value)", {
        'nom_etablissement' => "karrigel an ankou",
        'nom_commune' => 'kumun',
        'identifiant_de_l_etablissement' => '666667',
      }
    end
  end
end
