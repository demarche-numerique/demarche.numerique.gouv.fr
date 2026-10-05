# frozen_string_literal: true

describe EditableChamp::ProposedPrefillComponent, type: :component do
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:procedure) do
    create(:procedure,
           public_type_de_champs: [{ type: :text, libelle: 'Nom', stable_id: 99 }],
           private_type_de_champs: [
             {
               type: :referentiel,
               stable_id: 88,
               referentiel:,
               referentiel_mapping: { "$.nom" => { prefill: "1", prefill_stable_id: 99, type: "string" } },
             },
           ])
  end
  let(:dossier) { create(:dossier, :en_construction, procedure:) }
  let(:champ) { dossier.champ_data.find { it.stable_id == 88 } }

  subject { render_inline(described_class.new(champ:)) }

  context 'when the referentiel has proposed nothing yet' do
    it 'stays silent' do
      expect(subject.to_html).to be_blank
    end
  end

  context 'when an API call has proposed public champs' do
    before { champ.update_external_data!(data: { 'nom' => 'Dupont' }, value: 'JE-VALIDE', value_json: {}) }

    it 'names the champs that will be updated and offers to send them' do
      expect(subject).to have_text('Ces champs du formulaire seront mis à jour')
      expect(subject).to have_text('Nom')
      expect(subject).to have_button('Envoyer à l’usager')
    end
  end
end
