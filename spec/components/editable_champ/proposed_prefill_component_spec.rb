# frozen_string_literal: true

describe EditableChamp::ProposedPrefillComponent, type: :component do
  let(:referentiel) { create(:api_referentiel, :exact_match) }
  let(:procedure) do
    create(:procedure,
           public_type_de_champs: [
             { type: :text, libelle: 'Nom', stable_id: 99 },
             {
               type: :repetition,
               libelle: 'Dirigeants',
               stable_id: 310,
               mandatory: false,
               children: [{ type: :text, libelle: 'Nom du dirigeant', stable_id: 311 }],
             },
           ],
           private_type_de_champs: [
             {
               type: :referentiel,
               stable_id: 88,
               referentiel:,
               referentiel_mapping: {
                 "$.nom" => { prefill: "1", prefill_stable_id: 99, type: "string" },
                 "$.dirigeant[0].nom" => { prefill: "1", prefill_stable_id: 311, type: "string" },
               },
             },
           ])
  end
  let(:dossier) { create(:dossier, :en_construction, procedure:) }
  let(:champ) { dossier.champ_data.find { it.stable_id == 88 } }
  let(:data) { { 'nom' => 'Dupont', 'dirigeant' => [{ 'nom' => 'Jeanne' }, { 'nom' => 'Paul' }] } }

  subject { render_inline(described_class.new(champ:)) }

  context 'when the referentiel has proposed nothing yet' do
    it 'stays silent' do
      expect(subject.to_html).to be_blank
    end
  end

  context 'when an API call has proposed public champs' do
    before { champ.update_external_data!(data:, value: 'JE-VALIDE', value_json: {}) }

    it 'previews the proposed values as external data from the API domain' do
      expect(subject).to have_text("à partir de l’API beta.gouv.fr et le dossier de l’usager est prêt à être prérempli")
      expect(subject).to have_selector('.external-champ.trusted-data .source', text: /Source\W+beta\.gouv\.fr/)
      expect(subject).not_to have_text('rnb-api')
      expect(subject).to have_selector('.champ-row', text: /Nom :\s+Dupont/)
      expect(subject).to have_button('Préremplir le dossier et informer l’usager qu’il peut compléter son dossier')
    end

    it 'shows each added row, numbered, with its values' do
      expect(subject).to have_text('Ajout de l’élément « Dirigeants 1 »')
      expect(subject).to have_text('Ajout de l’élément « Dirigeants 2 »')
      expect(subject).to have_selector('.sub_list', text: /Nom du dirigeant :\s+Jeanne/)
      expect(subject).to have_selector('.sub_list', text: /Nom du dirigeant :\s+Paul/)
    end
  end

  context 'when the dossier can no longer go back to the usager' do
    let(:dossier) { create(:dossier, :accepte, procedure:) }

    before { champ.update_external_data!(data:, value: 'JE-VALIDE', value_json: {}) }

    it 'hides the proposal' do
      expect(dossier.instructeur_buffer_changes?).to be true
      expect(subject.to_html).to be_blank
    end
  end

  context 'when the API returns what the usager already has' do
    before do
      dossier.champ_data.find { it.stable_id == 99 }.update!(value: 'Dupont')
      champ.update_external_data!(data: { 'nom' => 'Dupont' }, value: 'JE-VALIDE', value_json: {})
    end

    it 'shows no card' do
      expect(subject.to_html).to be_blank
    end
  end

  context 'when the proposal replaces a value of the usager' do
    before do
      dossier.champ_data.find { it.stable_id == 99 }.update!(value: 'Martin')
      champ.update_external_data!(data:, value: 'JE-VALIDE', value_json: {})
    end

    it 'shows the value it replaces' do
      expect(subject).to have_selector('.champ-row', text: /Nom :\s+Dupont\s+\(remplace « Martin »\)/)
    end
  end

  context 'with a multiple choice list and a checkbox as targets' do
    let(:procedure) do
      create(:procedure,
             public_type_de_champs: [
               { type: :multiple_drop_down_list, libelle: 'Activités', stable_id: 97, options: ['Sport', 'Culture', 'Loisirs'] },
               { type: :checkbox, libelle: 'Adhérent', stable_id: 96 },
             ],
             private_type_de_champs: [
               {
                 type: :referentiel,
                 stable_id: 88,
                 referentiel:,
                 referentiel_mapping: {
                   "$.activites" => { prefill: "1", prefill_stable_id: 97, type: "array" },
                   "$.adherent" => { prefill: "1", prefill_stable_id: 96, type: "boolean" },
                 },
               },
             ])
    end

    before do
      dossier.champ_data.find { it.stable_id == 96 }.update!(value: 'false')
      champ.update_external_data!(data: { 'activites' => ['Sport', 'Culture'], 'adherent' => true }, value: 'JE-VALIDE', value_json: {})
    end

    it 'lists the chosen options, not a raw array' do
      expect(subject).to have_selector('.champ-row', text: /Activités :\s+Ajouté : Sport et Culture/)
    end

    it 'shows the "No" a checkbox replaces' do
      expect(subject).to have_selector('.champ-row', text: /Adhérent :\s+Oui\s+\(remplace « Non »\)/)
    end
  end
end
