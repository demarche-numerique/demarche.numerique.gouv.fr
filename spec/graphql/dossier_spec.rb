# frozen_string_literal: true

RSpec.describe Types::DossierType, type: :graphql do
  let(:query) { DOSSIER_QUERY }
  let(:context) { { internal_use: true } }
  let(:variables) { {} }

  subject { API::V2::Schema.execute(query, variables: variables, context: context) }

  let(:data) { subject['data'].deep_symbolize_keys }
  let(:errors) { subject['errors'] }

  describe 'dossier usager' do
    let(:dossier) { create(:dossier, :en_construction) }
    let(:variables) { { number: dossier.id } }

    it { expect(data[:dossier][:usager][:email]).to eq(dossier.user.email) }
  end

  describe 'dossier with attestation' do
    context 'when dossier is accepted' do
      let(:dossier) { create(:dossier, :accepte, :with_attestation_acceptation) }
      let(:query) { DOSSIER_WITH_ATTESTATION_QUERY }
      let(:variables) { { number: dossier.id } }

      it do
        expect(data[:dossier][:attestation]).not_to be_nil
        expect(data[:dossier][:traitements]).to eq([{ state: 'accepte' }])
        expect(data[:dossier][:dateExpiration]).not_to be_nil
      end

      context 'when attestation template is not activated' do
        before { dossier.procedure.attestation_acceptation_template.update(activated: false) }

        it { expect(data[:dossier][:attestation]).to be_nil }
      end
    end

    context 'when dossier is refused' do
      let(:dossier) { create(:dossier, :refuse, :with_attestation_refus) }
      let(:query) { DOSSIER_WITH_ATTESTATION_QUERY }
      let(:variables) { { number: dossier.id } }

      it do
        expect(data[:dossier][:attestation]).not_to be_nil
        expect(data[:dossier][:traitements]).to eq([{ state: 'refuse' }])
        expect(data[:dossier][:dateExpiration]).not_to be_nil
      end

      context 'when attestation template is not activated' do
        before { dossier.procedure.attestation_refus_template.update(activated: false) }

        it { expect(data[:dossier][:attestation]).to be_nil }
      end
    end

    context 'when dossier is refused but only acceptation template is activated' do
      let(:dossier) { create(:dossier, :refuse) }
      let(:query) { DOSSIER_WITH_ATTESTATION_QUERY }
      let(:variables) { { number: dossier.id } }

      before do
        dossier.procedure.attestation_acceptation_template = build(:attestation_template, activated: true)
        dossier.procedure.save!
      end

      it 'should not return attestation for refused dossier when only acceptation template exists' do
        expect(data[:dossier][:attestation]).to be_nil
      end
    end
  end

  describe 'dossier with champs' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :communes }, { type: :address }, { type: :siret }, { type: :rna }, { type: :header_section }, { type: :explication }]) }
    let(:dossier) { create(:dossier, :accepte, :with_populated_champs, procedure: procedure) }
    let(:query) { DOSSIER_WITH_CHAMPS_QUERY }
    let(:variables) { { number: dossier.id } }
    let(:address) do
      {
        "type" => "housenumber",
        "label" => "33 Rue Rébeval 75019 Paris",
        "city_code" => "75119",
        "city_name" => "Paris",
        "postal_code" => "75019",
        "region_code" => "11",
        "region_name" => "Île-de-France",
        "street_name" => "Rue Rébeval",
        "street_number" => "33",
        "street_address" => "33 Rue Rébeval",
        "department_code" => "75",
        "department_name" => "Paris",
        "country_code" => "FR",
        "country_name" => "France",
      }
    end

    let(:not_in_ban_address) do
      {
        not_in_ban: 'true',
        label: "2 rue des Démarches grenoble (38100)",
        city_code: "38100",
        city_name: "grenoble",
        postal_code: "38000",
        region_code: "84",
        region_name: "Auvergne-Rhones-Alpes",
        street_address: "2 rue des Démarches",
        department_code: "38",
        department_name: "Isère",
        country_code: "FR",
        country_name: "France",
      }.stringify_keys
    end

    let(:international_address) do
      {
        not_in_ban: 'true',
        label: "2 rue des Démarches Roma (1234)",
        city_name: "Roma",
        postal_code: "1234",
        street_address: "2 rue des Démarches",
        department_code: "99",
        department_name: APIGeoService.departement_name('99'),
        country_code: "IT",
        country_name: APIGeoService.country_name('IT'),
      }.stringify_keys
    end

    let(:rna) do
      {
        "adresse" => {
          "commune" => "Paris 14e",
          "type_voie" => "RUE",
          "code_insee" => "75114",
          "complement" => nil,
          "code_postal" => "75512",
          "numero_voie" => "12",
          "distribution" => nil,
          "libelle_voie" => "xyz",
        },
       "association_rna" => "W173847273",
       "association_objet" => "prévenir",
       "association_titre" => "CROIX ROUGE",
       "association_date_creation" => "1964-12-30",
       "association_date_declaration" => "2022-08-10",
      }
    end

    before do
      dossier.root_champs_public.find { _1.type_champ == TypeDeChamp.type_champs.fetch(:address) }.update(value_json: address)
      dossier.root_champs_public.find { _1.type_champ == TypeDeChamp.type_champs.fetch(:rna) }.update(data: rna)
    end

    it '', :slow do
      expect(data[:dossier][:champs].map { _1[:__typename] }).to eq ["CommuneChamp", "AddressChamp", "SiretChamp", "RNAChamp", "HeaderSectionChamp", "ExplicationChamp"]

      expect(data[:dossier][:champs][1][:commune][:code]).to eq('75119')
      expect(data[:dossier][:champs][1][:commune][:postalCode]).to eq('75019')
      expect(data[:dossier][:champs][1][:departement][:code]).to eq('75')
      expect(data[:dossier][:champs][2][:etablissement][:siret]).to eq dossier.root_champs_public[2].etablissement.siret

      expect(data[:dossier][:revision][:champDescriptors].map { _1[:level] }).to eq([nil, nil, nil, nil, 1, nil])
      expect(data[:dossier][:revision][:champDescriptors].map { _1[:__typename] }).to eq ["CommuneChampDescriptor", "AddressChampDescriptor", "SiretChampDescriptor", "RNAChampDescriptor", "HeaderSectionChampDescriptor", "ExplicationChampDescriptor"]
      expect(data[:dossier][:champs].map { _1[:id] }).to eq(data[:dossier][:revision][:champDescriptors].map { _1[:id] })

      expect(data[:dossier][:champs][1][:address][:cityName]).to eq('Paris 19e Arrondissement')
      expect(data[:dossier][:champs][1][:address][:departmentName]).to eq('Paris')
      expect(data[:dossier][:champs][1][:address][:regionName]).to eq('Île-de-France')

      expect(data[:dossier][:champs][3][:rna][:id]).to eq('W173847273')
      expect(data[:dossier][:champs][3][:rna][:title]).to eq('CROIX ROUGE')
      expect(data[:dossier][:champs][3][:rna][:address][:label]).to eq('12 RUE xyz 75512 Paris 14e')
      expect(data[:dossier][:champs][3][:rna][:address][:streetNumber]).to eq('12')
      expect(data[:dossier][:champs][3][:rna][:address][:cityName]).to eq('Paris 14e')
      expect(data[:dossier][:champs][3][:rna][:address][:departmentName]).to eq(nil)
      expect(data[:dossier][:champs][3][:rna][:address][:regionName]).to eq(nil)
    end

    context 'not in ban' do
      before do
        dossier.root_champs_public.find(&:address?).update_columns(value_json: not_in_ban_address)
      end

      it 'should return address', :slow do
        expect(errors).to be_nil
        expect(data[:dossier][:champs][1][:__typename]).to eq "AddressChamp"
        expect(data[:dossier][:champs][1][:address][:departmentName]).to eq('Isère')
        expect(data[:dossier][:champs][1][:address][:countryName]).to eq('France')
      end
    end

    context 'international' do
      before do
        dossier.root_champs_public.find(&:address?).update_columns(value_json: international_address)
      end

      it 'should return address', :slow do
        expect(errors).to be_nil
        expect(data[:dossier][:champs][1][:__typename]).to eq "AddressChamp"
        expect(data[:dossier][:champs][1][:address][:departmentName]).to eq('Etranger')
        expect(data[:dossier][:champs][1][:address][:countryName]).to eq('Italie')
      end
    end

    context 'when etablissement is in degraded mode' do
      let(:etablissement) { dossier.root_champs_public.third.etablissement }
      before do
        etablissement.update(adresse: nil)
      end

      it do
        expect(etablissement).to be_as_degraded_mode
        expect(data[:dossier][:champs][2][:__typename]).to eq "SiretChamp"
        expect(data[:dossier][:champs][2][:etablissement]).to be_nil
      end
    end
  end

  describe 'dossier with annotations' do
    let(:procedure) { create(:procedure, :published, private_type_de_champs: [{ type: :engagement_juridique }]) }
    let(:dossier) { create(:dossier, :accepte, :with_populated_champs, procedure: procedure) }
    let(:query) { DOSSIER_WITH_ANNOTATIONS_QUERY }
    let(:variables) { { number: dossier.id } }

    it do
      expect(data[:dossier][:annotations][0][:__typename]).to eq "EngagementJuridiqueChamp"
    end
  end

  describe 'dossier with selected champ' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ libelle: 'yolo' }, { libelle: 'toto' }]) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
    let(:query) { DOSSIER_WITH_SELECTED_CHAMP_QUERY }
    let(:variables) { { number: dossier.id, id: champ.to_typed_id } }
    let(:champ) { dossier.root_champs_public.last }

    context 'when champ exists' do
      it {
        expect(data[:dossier][:champs].size).to eq 1
        expect(data[:dossier][:champs][0][:label]).to eq "toto"
      }
    end

    context "when champ dosen't exists" do
      let(:variables) { { number: dossier.id, id: '1234' } }

      it { expect(data[:dossier][:champs].size).to eq 0 }
    end
  end

  describe 'dossier with conditional champs' do
    include Logic
    let(:stable_id) { generate(:stable_id) }
    let(:condition) { ds_eq(champ_value(stable_id), constant(true)) }
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :checkbox, stable_id: stable_id }, { type: :text, condition: condition }]) }
    let(:dossier) { create(:dossier, :accepte, :with_populated_champs, procedure: procedure) }
    let(:query) { DOSSIER_WITH_CHAMPS_QUERY }
    let(:variables) { { number: dossier.id } }
    let(:checkbox_value) { 'true' }

    before do
      dossier.root_champs_public.first.update(value: checkbox_value)
    end

    context 'when checkbox is true' do
      it do
        expect(data[:dossier][:champs].size).to eq 2
        expect(data[:dossier][:champs][0][:__typename]).to eq "CheckboxChamp"
        expect(data[:dossier][:champs][1][:__typename]).to eq "TextChamp"
      end
    end

    context 'when checkbox is false' do
      let(:checkbox_value) { 'false' }
      it do
        expect(data[:dossier][:champs].size).to eq 1
        expect(data[:dossier][:champs][0][:__typename]).to eq "CheckboxChamp"
      end
    end
  end

  describe 'dossier with user' do
    let(:dossier) { create(:dossier, :en_construction) }
    let(:query) { DOSSIER_WITH_USAGER_QUERY }
    let(:variables) { { number: dossier.id } }

    it { expect(data[:dossier][:usager]).not_to be_nil }
  end

  describe 'dossier with deleted user' do
    let(:dossier) { create(:dossier, :en_construction) }
    let(:query) { DOSSIER_WITH_USAGER_QUERY }
    let(:variables) { { number: dossier.id } }
    let(:email) { dossier.user.email }

    before do
      dossier.update(user_id: nil, deleted_user_email_never_send: email)
    end

    it {
      expect(data[:dossier][:usager]).not_to be_nil
      expect(data[:dossier][:usager][:email]).to eq(email)
      expect(data[:dossier][:usager][:id]).to eq('<deleted>')
    }
  end

  describe 'dossier with linked dossier' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :dossier_link }]) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }
    let(:linked_dossier) { create(:dossier, :en_construction) }
    let(:query) { DOSSIER_WITH_LINKED_DOSIER_QUERY }
    let(:variables) { { number: dossier.id } }

    before do
      dossier.root_champs_public.first.update(value: linked_dossier.id)
    end

    context 'en_construction' do
      it {
        expect(data[:dossier][:champs].first).not_to be_nil
        expect(data[:dossier][:champs].first[:dossier][:id]).to eq(linked_dossier.to_typed_id)
        expect(data[:dossier][:champs].first[:dossier][:state]).to eq('en_construction')
      }
    end

    context 'brouillon' do
      let(:linked_dossier) { create(:dossier, :brouillon) }

      it {
        expect(data[:dossier][:champs].first).not_to be_nil
        expect(data[:dossier][:champs].first[:dossier]).to be_nil
      }
    end
  end

  describe 'dossier with repetition' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :repetition, children: [{ libelle: 'Nom' }, { libelle: 'Age' }] }]) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }
    let(:linked_dossier) { create(:dossier, :en_construction) }
    let(:query) { DOSSIER_WITH_REPETITION_QUERY }
    let(:variables) { { number: dossier.id } }

    let(:rows) do
      dossier.root_champs_public.first.rows.map do |champs|
        { champs: champs.map { { id: _1.to_typed_id } } }
      end
    end

    it {
      expect(data[:dossier][:champs].first).not_to be_nil
      expect(data[:dossier][:champs].first[:rows]).not_to be_nil
      expect(data[:dossier][:champs].first[:rows].size).to eq(2)
      expect(data[:dossier][:champs].first[:rows]).to eq(rows)
    }
  end

  describe 'dossier with large integer in columns' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ libelle: 'Montant', type: :integer_number }]) }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure: procedure) }
    let(:query) { DOSSIER_WITH_INTEGER_COLUMNS_QUERY }
    let(:variables) { { number: dossier.id } }
    let(:large_integer) { 3400936534933 }

    before do
      integer_champ = dossier.root_champs_public.first
      integer_champ.update(value: large_integer.to_s)
    end

    it 'handles large integers in columns without error' do
      expect(errors).to be_nil
      expect(data[:dossier][:champs].first).not_to be_nil

      # Verify the large integer is returned correctly in the columns field
      integer_champ = data[:dossier][:champs].first
      expect(integer_champ[:columns]).not_to be_empty

      integer_column = integer_champ[:columns].find { |col| col[:__typename] == 'IntegerColumn' }
      expect(integer_column).not_to be_nil
      # BigInt values are returned as strings to avoid precision loss in JavaScript
      expect(integer_column[:value]).to eq(large_integer.to_s)
    end
  end

  describe 'dossier with piece justificative nature=titre_identite filled' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
    let(:dossier) { create(:dossier, :accepte, :with_populated_champs, procedure: procedure) }

    let(:query) { DOSSIER_WITH_TITRE_IDENTITE_QUERY }
    let(:variables) { { number: dossier.id } }

    it 'returns TitreIdentiteChamp type' do
      expect(data[:dossier][:champs][0][:__typename]).to eq('TitreIdentiteChamp')
      expect(data[:dossier][:champs][0][:filled]).to eq(true)
    end
  end

  describe 'dossier with piece justificative nature=titre_identite does not expose sensitive data' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
    let(:dossier) { create(:dossier, :accepte, :with_populated_champs, procedure: procedure) }
    let(:query) { DOSSIER_WITH_PIECE_JUSTIFICATIVE_COLUMNS_AND_FILES_QUERY }
    let(:variables) { { number: dossier.id } }

    it 'returns empty files and no attachment columns' do
      champ = data[:dossier][:champs][0]
      expect(champ[:__typename]).to eq('PieceJustificativeChamp')
      expect(data[:dossier][:champs][0].key?(:filled)).to eq(false)
      expect(champ[:files]).to eq([])
      expect(champ[:columns].none? { _1[:__typename] == 'AttachmentsColumn' }).to eq(true)
    end
  end

  describe 'dossier with piece justificative nature=titre_identite not filled' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :piece_justificative, nature: 'titre_identite' }]) }
    let(:dossier) { create(:dossier, :accepte, procedure: procedure) }

    let(:query) { DOSSIER_WITH_TITRE_IDENTITE_QUERY }
    let(:variables) { { number: dossier.id } }

    it 'returns TitreIdentiteChamp type' do
      expect(data[:dossier][:champs][0][:__typename]).to eq('TitreIdentiteChamp')
      expect(data[:dossier][:champs][0][:filled]).to eq(false)
    end
  end

  describe 'dossier with motivation attachment' do
    let(:dossier) { create(:dossier, :accepte, :with_motivation, :with_justificatif) }
    let(:query) { DOSSIER_WITH_MOTIVATION_QUERY }
    let(:variables) { { number: dossier.id } }

    it {
      expect(data[:dossier][:motivationAttachment][:url]).not_to be_nil
    }
  end

  describe 'dossier with message with no attachments' do
    let(:dossier) { dossiers.en_construction }
    let(:query) { DOSSIER_WITH_MESSAGE_QUERY }
    let(:variables) { { number: dossier.id } }

    it {
      expect(data[:dossier][:messages]).not_to be_nil
      expect(data[:dossier][:messages][0][:correction]).to be_nil
    }
  end

  describe 'dossier with pending correction' do
    let(:dossier) { create(:dossier, :en_construction) }
    let!(:correction) { create(:dossier_correction, dossier:) }
    let(:query) { DOSSIER_WITH_CORRECTION_QUERY }
    let(:variables) { { number: dossier.id } }

    it {
      expect(data[:dossier][:messages][0][:correction]).to eq({ reason: "incorrect", dateResolution: nil })
      expect(data[:dossier][:dateDerniereCorrectionEnAttente]).not_to be_nil
    }
  end

  describe 'dossier on sva procedure' do
    let(:procedure) { create(:procedure, :sva) }
    let(:query) { DOSSIER_WITH_SVA_QUERY }
    let(:variables) { { number: dossier.id } }

    context 'dossier en_instruction' do
      let(:dossier) { create(:dossier, :en_instruction, procedure:, sva_svr_decision_on: 3.days.from_now.to_date) }

      it {
        expect(data[:dossier][:datePrevisionnelleDecisionSVASVR]).not_to be_nil
      }
    end

    context 'dossier accepte' do
      let(:dossier) { create(:dossier, :accepte, procedure:, sva_svr_decision_triggered_at: 24.hours.ago) }

      it {
        expect(data[:dossier][:dateTraitementSVASVR]).not_to be_nil
      }
    end
  end

  describe 'dossier with labels' do
    let(:procedure) { create(:procedure, :published) }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let(:label) { create(:label, procedure:, name: "Urgent", color: "pink_macaron") }
    let(:query) { DOSSIER_WITH_LABELS_QUERY }
    let(:variables) { { number: dossier.id } }

    let(:past) { DateTime.new(2025, 1, 5, 12, 30, 0, "+01:00") }
    before do
      travel_to past do
        dossier.labels << label
      end
    end

    it {
      expect(data[:dossier][:labels]).not_to be_empty
      expect(data[:dossier][:labels][0]).to eq(
        {
          id: label.to_typed_id,
          name: "Urgent",
          color: "pink_macaron",
        }
      )
    }
  end

  describe 'dossier with assignments' do
    let(:procedure) { create(:procedure, :published, :routee, :for_individual) }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
    let(:instructeur) { create(:instructeur) }
    let(:autre_groupe) { procedure.groupe_instructeurs.last }
    let(:query) { DOSSIER_WITH_ASSIGNMENTS_QUERY }
    let(:variables) { { number: dossier.id } }

    before do
      dossier.assign_to_groupe_instructeur(autre_groupe, DossierAssignment.modes.fetch(:manual), instructeur)
      dossier.assign_to_groupe_instructeur(procedure.defaut_groupe_instructeur, DossierAssignment.modes.fetch(:auto))
    end

    it 'returns the assignment history' do
      expect(errors).to be_nil

      assignment = data[:dossier][:assignments].find { it[:mode] == 'manual' }
      expect(assignment).to eq(
        {
          mode: 'manual',
          assignedAt: dossier.dossier_assignments.manual.last.assigned_at.iso8601,
          assignedBy: instructeur.email,
          groupeInstructeurNumber: autre_groupe.id,
          groupeInstructeurLabel: 'deuxième groupe',
          previousGroupeInstructeurNumber: procedure.defaut_groupe_instructeur.id,
          previousGroupeInstructeurLabel: procedure.defaut_groupe_instructeur.label,
        }
      )
    end

    it 'returns assignments in chronological order' do
      expect(data[:dossier][:assignments].map { it[:mode] }.last(2)).to eq(['manual', 'auto'])
    end

    context 'when filtering on a mode' do
      let(:variables) { { number: dossier.id, mode: 'manual' } }

      it { expect(data[:dossier][:assignments].map { it[:mode] }).to eq(['manual']) }
    end

    context 'when the groupe instructeur has been renamed' do
      before { autre_groupe.update!(label: 'nouveau nom') }

      it 'keeps the label as it was at assignment time' do
        assignment = data[:dossier][:assignments].find { it[:mode] == 'manual' }
        expect(assignment[:groupeInstructeurLabel]).to eq('deuxième groupe')
      end
    end

    context 'when the groupe instructeur has been deleted' do
      before { autre_groupe.destroy! }

      it 'keeps the historical label but has no number' do
        assignment = data[:dossier][:assignments].find { it[:mode] == 'manual' }
        expect(assignment[:groupeInstructeurNumber]).to be_nil
        expect(assignment[:groupeInstructeurLabel]).to eq('deuxième groupe')
      end
    end
  end

  describe 'dossier with date and datetime champs' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :date }, { type: :datetime }]) }
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let(:query) { DOSSIER_WITH_DATE_CHAMPS_QUERY }
    let(:variables) { { number: dossier.id } }

    let(:champ_date) { dossier.root_champs_public.first }
    let(:champ_datetime) { dossier.root_champs_public.second }

    before do
      champ_date.update(value: '2026-01-01')
      champ_datetime.update(value: '2026-01-01T12:12:00+01:00')
    end

    it 'returns date and datetime in the expected format' do
      expect(errors).to be_nil
      expect(data[:dossier][:champs][0][:stringValue]).to eq('01 janvier 2026')
      expect(data[:dossier][:champs][1][:stringValue]).to eq('01 janvier 2026 12:12')
    end
  end

  describe 'dossier with personne morale naf_2025' do
    let(:procedure) { create(:procedure) }
    let(:etablissement) { create(:etablissement, libelle_naf: nil, naf_2025: '84.11', libelle_naf_2025: 'Administration publique générale') }
    let(:dossier) { create(:dossier, :en_construction, procedure:, etablissement:) }
    let(:query) { DOSSIER_WITH_PERSONNE_MORALE_QUERY }
    let(:variables) { { number: dossier.id } }

    it 'falls back libelle_naf to libelle_naf_2025 when nil' do
      demandeur = data[:dossier][:demandeur]
      expect(demandeur[:naf2025]).to eq('84.11')
      expect(demandeur[:libelleNaf2025]).to eq('Administration publique générale')
    end
  end

  DOSSIER_WITH_PERSONNE_MORALE_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      demandeur {
        ... on PersonneMorale {
          naf2025
          libelleNaf2025
        }
      }
    }
  }
  GRAPHQL

  describe 'dossier with traitement changed columns' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:public_type_de_champs) do
      [
        { type: :text, libelle: "Texte", stable_id: 99 },
        { type: :text, libelle: "Autre texte", stable_id: 991 },
        { type: :repetition, libelle: "Répétition", stable_id: 993, children: [{ type: :text, libelle: 'Nom', stable_id: 994 }] },
      ]
    end
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
    let(:query) { DOSSIER_WITH_TRAITEMENTS_CHANGED_COLUMNS_QUERY }
    let(:variables) { { number: dossier.id } }

    let(:traitements) { data[:dossier][:traitements] }

    context 'when the only traitement is the initial depose' do
      it 'exposes an empty changedColumns list' do
        expect(errors).to be_nil
        expect(traitements.size).to eq(1)
        expect(traitements.first[:event]).to eq('depose')
        expect(traitements.first[:changedColumns]).to eq([])
      end
    end

    context 'when the usager submits a correction' do
      before do
        dossier.with_update_stream(dossier.user) do
          dossier.public_champ_for_update('99', updated_by: dossier.user.email)
            .assign_attributes(value: "Nouvelle valeur")
        end
        dossier.save!
        dossier.usager_submit_en_construction!
      end

      it 'exposes the changed column for the modified champ' do
        expect(errors).to be_nil

        correction = traitements.find { _1[:event] == 'depose_correction_usager' }
        expect(correction).not_to be_nil
        expect(correction[:changedColumns]).to contain_exactly(
          a_hash_including(label: "Texte", stringValue: "Nouvelle valeur")
        )
      end

      it 'exposes a global id for the changed column' do
        expect(errors).to be_nil

        correction = traitements.find { _1[:event] == 'depose_correction_usager' }
        expect(correction[:changedColumns].first[:id]).to eq(GraphQL::Schema::UniqueWithinType.encode('Column', 'type_de_champ/99'))
      end
    end

    context 'when the usager corrects a champ inside a repetition' do
      let(:row_id) do
        type_de_champ = dossier.find_type_de_champ_by_stable_id(993)
        dossier.project_champ(type_de_champ).row_ids.first
      end

      before do
        dossier.with_update_stream(dossier.user) do
          dossier.public_champ_for_update("994-#{row_id}", updated_by: dossier.user.email)
            .assign_attributes(value: "Valeur dans la répétition")
        end
        dossier.save!
        dossier.usager_submit_en_construction!
      end

      it 'exposes the changed column for the repetition child' do
        expect(errors).to be_nil

        correction = traitements.find { _1[:event] == 'depose_correction_usager' }
        expect(correction[:changedColumns].map { _1[:stringValue] })
          .to include("Valeur dans la répétition")
      end
    end

    context 'when an instructeur submits a correction' do
      let(:instructeur) { create(:instructeur) }

      before do
        dossier.with_instructeur_buffer_stream do
          dossier.public_champ_for_update('99', updated_by: instructeur.email)
            .assign_attributes(value: "Correction instructeur")
        end
        dossier.save!
        dossier.instructeur_submit_en_construction!(instructeur:)
      end

      it 'exposes the changed column for the modified champ' do
        expect(errors).to be_nil

        correction = traitements.find { _1[:event] == 'depose_correction_instructeur' }
        expect(correction).not_to be_nil
        expect(correction[:changedColumns]).to contain_exactly(
          a_hash_including(label: "Texte", stringValue: "Correction instructeur")
        )
      end
    end
  end

  describe 'dossier with traitement changed columns of type geojson and attachments' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:public_type_de_champs) do
      [
        { type: :carte, libelle: "Carte", stable_id: 996 },
        { type: :piece_justificative, libelle: "Pièce", stable_id: 997 },
      ]
    end
    let(:dossier) { create(:dossier, :en_construction, procedure:) }
    let(:query) { DOSSIER_WITH_TRAITEMENTS_TYPED_CHANGED_COLUMNS_QUERY }
    let(:variables) { { number: dossier.id, includeGeometry: true } }

    let(:traitements) { data[:dossier][:traitements] }
    let(:correction) { traitements.find { _1[:event] == 'depose_correction_usager' } }

    context 'when the usager adds geometry to a carte champ' do
      let(:geo_area) { build(:geo_area, :selection_utilisateur, :polygon) }

      before do
        dossier.with_update_stream(dossier.user) do
          champ = dossier.public_champ_for_update('996', updated_by: dossier.user.email)
          champ.update(geo_areas: [geo_area])
        end
        dossier.save!
        dossier.usager_submit_en_construction!
      end

      it 'exposes a GeoJSONColumn with its features' do
        expect(errors).to be_nil

        geo_column = correction[:changedColumns].find { _1[:__typename] == 'GeoJSONColumn' }
        expect(geo_column).not_to be_nil
        expect(geo_column[:label]).to eq("Carte")
        expect(geo_column[:value].size).to eq(1)
        expect(geo_column[:value][0][:geometry][:type]).to eq("Polygon")
        expect(geo_column[:value][0][:geometry][:coordinates]).not_to be_nil
      end
    end

    context 'when the usager attaches a file to a piece justificative champ' do
      before do
        dossier.with_update_stream(dossier.user) do
          champ = dossier.public_champ_for_update('997', updated_by: dossier.user.email)
          champ.piece_justificative_file.attach(io: Rails.root.join('spec/fixtures/files/Contrat.pdf').open, filename: 'Contrat.pdf')
          champ.save!
        end
        dossier.save!
        dossier.usager_submit_en_construction!
      end

      it 'exposes an AttachmentsColumn with the attached file' do
        expect(errors).to be_nil

        attachments_column = correction[:changedColumns].find { _1[:__typename] == 'AttachmentsColumn' }
        expect(attachments_column).not_to be_nil
        expect(attachments_column[:label]).to eq("Pièce")
        expect(attachments_column[:value].map { _1[:filename] }).to eq(['Contrat.pdf'])
        expect(attachments_column[:value][0][:url]).not_to be_nil
      end
    end
  end

  describe 'dossier with several carte champs' do
    let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
    let(:public_type_de_champs) do
      [
        { type: :carte, libelle: "Carte 1" },
        { type: :carte, libelle: "Carte 2" },
        { type: :carte, libelle: "Carte 3" },
      ]
    end
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:) }
    let(:query) { DOSSIER_WITH_GEOJSON_COLUMNS_QUERY }
    let(:variables) { { number: dossier.id } }

    before do
      dossier.champ_data.each { _1.update(geo_areas: [build(:geo_area, :selection_utilisateur, :polygon)]) }
    end

    it 'loads every geo_area in a single query' do
      dossier # create before counting

      count = 0
      callback = lambda { |*args| count += 1 if args.last[:sql].include?('geo_areas') }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { subject }

      expect(errors).to be_nil
      geo_columns = data[:dossier][:champs].flat_map { _1[:columns] }.filter { _1[:__typename] == 'GeoJSONColumn' }
      expect(geo_columns.map { _1[:value].size }).to eq([1, 1, 1])
      expect(count).to eq(1)
    end
  end

  DOSSIER_WITH_GEOJSON_COLUMNS_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      champs {
        label
        columns {
          __typename
          ... on GeoJSONColumn {
            value {
              geometry {
                type
              }
            }
          }
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      id
      number
      usager {
        email
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_TRAITEMENTS_CHANGED_COLUMNS_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      traitements {
        event
        changedColumns {
          id
          label
          stringValue
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_TRAITEMENTS_TYPED_CHANGED_COLUMNS_QUERY = <<-GRAPHQL
  query($number: Int!, $includeGeometry: Boolean = false) {
    dossier(number: $number) {
      traitements {
        event
        changedColumns {
          __typename
          label
          ... on GeoJSONColumn {
            value {
              geometry @include(if: $includeGeometry) {
                type
                coordinates
              }
            }
          }
          ... on AttachmentsColumn {
            value {
              url
              filename
            }
          }
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_USAGER_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      id
      number
      usager {
        id
        email
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_ATTESTATION_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      attestation {
        url
      }
      traitements {
        state
      }
      dateExpiration
    }
  }
  GRAPHQL

  DOSSIER_WITH_MOTIVATION_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      motivationAttachment {
        url
      }
    }
  }
  GRAPHQL
  DOSSIER_WITH_ANNOTATIONS_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      id
      number
      annotations {
        id
        label
        __typename
        ... on EngagementJuridiqueChamp {
          engagementJuridique {
            ...EngagementJuridiqueFragment
          }
        }
      }
    }
  }
  fragment EngagementJuridiqueFragment on EngagementJuridique {
    montantEngage
    montantPaye
  }

  GRAPHQL
  DOSSIER_WITH_CHAMPS_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      id
      number
      revision {
        champDescriptors {
          __typename
          id
          label
          ... on HeaderSectionChampDescriptor {
            level
          }
        }
      }
      champs {
        id
        label
        __typename
        ...CommuneChampFragment
        ...RNAChampFragment
        ... on AddressChamp {
          address {
            ...AddressFragment
          }
          commune {
            ...CommuneFragment
          }
          departement {
            name
            code
          }
        }
        ... on SiretChamp {
          etablissement {
            siret
            entreprise { capitalSocial }
          }
        }
        ... on HeaderSectionChamp {
          level
        }
        ... on ExplicationChamp {}
      }
    }
  }
  fragment CommuneChampFragment on CommuneChamp {
    commune {
      ...CommuneFragment
    }
    departement {
      name
      code
    }
  }
  fragment CommuneFragment on Commune {
    name
    code
    postalCode
  }
  fragment AddressFragment on Address {
    type
    label
    cityName
    cityCode
    streetName
    streetNumber
    departmentName
    regionName
    countryCode
    countryName
  }

  fragment RNAChampFragment on RNAChamp {
    stringValue
    rna {
      id
      title
      address {
        ...AddressFragment
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_LINKED_DOSIER_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      champs {
        id
        ... on DossierLinkChamp {
          dossier {
            id
            state
          }
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_REPETITION_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      champs {
        id
        ... on RepetitionChamp {
          rows {
            champs { id }
          }
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_INTEGER_COLUMNS_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      champs {
        id
        columns {
          __typename
          label
          ... on IntegerColumn {
            value
          }
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_PIECE_JUSTIFICATIVE_COLUMNS_AND_FILES_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      id
      number
      champs {
        id
        label
        __typename
        ... on PieceJustificativeChamp {
          files {
            url
            filename
          }
        }
        columns {
          __typename
          label
          ... on AttachmentsColumn {
            value {
              url
              filename
            }
          }
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_TITRE_IDENTITE_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      id
      number
      champs {
        id
        label
        __typename
        ... on TitreIdentiteChamp {
          filled
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_MESSAGE_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      messages {
        body
        attachments {
          filename
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_CORRECTION_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      dateDerniereCorrectionEnAttente
      messages {
        body
        correction {
          reason
          dateResolution
        }
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_SVA_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      datePrevisionnelleDecisionSVASVR
      dateTraitementSVASVR
    }
  }
  GRAPHQL

  DOSSIER_WITH_SELECTED_CHAMP_QUERY = <<-GRAPHQL
  query($number: Int!, $id: ID!) {
    dossier(number: $number) {
      champs(id: $id) {
        id
        label
      }
    }
  }
  GRAPHQL

  DOSSIER_WITH_LABELS_QUERY = <<-GRAPHQL
    query($number: Int!) {
      dossier(number: $number) {
        labels {
          id
          name
          color
        }
      }
    }
  GRAPHQL

  DOSSIER_WITH_ASSIGNMENTS_QUERY = <<-GRAPHQL
    query($number: Int!, $mode: DossierAssignmentMode) {
      dossier(number: $number) {
        assignments(mode: $mode) {
          mode
          assignedAt
          assignedBy
          groupeInstructeurNumber
          groupeInstructeurLabel
          previousGroupeInstructeurNumber
          previousGroupeInstructeurLabel
        }
      }
    }
  GRAPHQL

  DOSSIER_WITH_DATE_CHAMPS_QUERY = <<-GRAPHQL
  query($number: Int!) {
    dossier(number: $number) {
      champs {
        id
        label
        stringValue
        __typename
        ... on DateChamp {
          date
        }
        ... on DatetimeChamp {
          datetime
        }
      }
    }
  }
  GRAPHQL
end
