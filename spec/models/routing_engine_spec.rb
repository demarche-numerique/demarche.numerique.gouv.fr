# frozen_string_literal: true

describe RoutingEngine, type: :model do
  include Logic

  describe '.compute' do
    let(:dossier) { create(:dossier, procedure:) }
    let(:defaut_groupe) { procedure.defaut_groupe_instructeur }
    let(:gi_2) { procedure.groupe_instructeurs.create(label: 'a second group') }

    subject do
      procedure.update_all_groupes_rule_statuses
      RoutingEngine.compute(dossier)
      dossier.groupe_instructeur
    end

    context 'with a drop down list type de champ' do
      let(:procedure) do
        create(:procedure,
          types_de_champ_public: [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }]).tap do |p|
          p.groupe_instructeurs.create(label: 'a third group')
        end
      end

      let(:drop_down_tdc) { procedure.draft_revision.types_de_champ.first }

      context 'without any rules' do
        it { is_expected.to eq(defaut_groupe) }
      end

      context 'without any matching rules' do
        before do
          procedure.groupe_instructeurs.each do |gi|
            gi.update(routing_rule: ds_eq(constant(false), constant(true)))
          end
        end

        it { is_expected.to eq(defaut_groupe) }
      end

      context 'with rules not configured yet' do
        before do
          procedure.groupe_instructeurs.each do |gi|
            gi.update(routing_rule: ds_eq(empty, empty))
          end
        end

        it { is_expected.to eq(defaut_groupe) }
      end

      context 'with a matching rule' do
        before do
          gi_2.update(routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')))
          dossier.champs.first.update(value: 'Lyon')
        end

        it { is_expected.to eq(gi_2) }
      end

      context 'with a closed gi with a matching rule' do
        before { gi_2.update(routing_rule: constant(true), closed: true) }

        it { is_expected.to eq(defaut_groupe) }
      end

      context 'with a non equals rule' do
        before do
          gi_2.update(routing_rule: ds_not_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')))
          dossier.champs.first.update(value: 'Paris')
        end

        it do
          is_expected.not_to eq(defaut_groupe)
          is_expected.to eq(gi_2)
        end
      end
    end

    context 'with a departements type de champ' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [{ type: :departements }]).tap do |p|
          p.groupe_instructeurs.create(label: 'a third group')
        end
      end

      let(:departements_tdc) { procedure.draft_revision.types_de_champ.first }

      context 'with a matching rule' do
        before do
          gi_2.update(routing_rule: ds_eq(champ_value(departements_tdc.stable_id), constant('43')))
          dossier.champs.first.update(value: 'Haute-Loire')
        end

        it { is_expected.to eq(gi_2) }
      end
    end

    context 'with a regions type de champ' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [{ type: :regions }]).tap do |p|
          p.groupe_instructeurs.create(label: 'a third group')
        end
      end

      let(:regions_tdc) { procedure.draft_revision.types_de_champ.first }

      context 'with a matching rule' do
        before do
          gi_2.update(routing_rule: ds_eq(champ_value(regions_tdc.stable_id), constant('04')))
          dossier.champs.first.update(value: 'La Réunion')
        end

        it { is_expected.to eq(gi_2) }
      end
    end

    context 'with a communes type de champ' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [{ type: :communes }]).tap do |p|
          p.groupe_instructeurs.create(label: 'a third group')
        end
      end

      let(:communes_tdc) { procedure.draft_revision.types_de_champ.first }

      context 'with a matching rule' do
        before do
          gi_2.update(routing_rule: ds_in_departement(champ_value(communes_tdc.stable_id), constant('92')))
          dossier.champs.first.update(code_postal: '92500', external_id: '92063')
        end

        it { is_expected.to eq(gi_2) }
      end
    end

    context 'with an epci type de champ' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [{ type: :epci }]).tap do |p|
          p.groupe_instructeurs.create(label: 'a third group')
        end
      end

      let(:epci_tdc) { procedure.draft_revision.types_de_champ.first }

      context 'with a matching rule' do
        before do
          gi_2.update(routing_rule: ds_in_departement(champ_value(epci_tdc.stable_id), constant('42')))
          dossier.champs.first.update_columns(
            external_id: 244200895,
            value: 'CC du Pilat Rhodanien',
            value_json: { code_departement: '42' }
          )
        end

        it do
          is_expected.to eq(gi_2)
        end
      end
    end

    context 'with an address type de champ' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [{ type: :address }]).tap do |p|
          p.groupe_instructeurs.create(label: 'a third group')
        end
      end

      let(:address_tdc) { procedure.draft_revision.types_de_champ.first }

      context 'with a matching rule' do
        before do
          gi_2.update(routing_rule: ds_in_departement(champ_value(address_tdc.stable_id), constant('42')))
          dossier.champs.first.update_columns(
            value: "2 rue de l'Hôtel de Ville 42000 Saint-Étienne",
            value_json: { department_code: '42', region_code: '83', city_code: '42218', postal_code: '42000', street_address: "2 rue de l'Hôtel de Ville", country_code: 'FR' }
          )
        end

        it do
          is_expected.to eq(gi_2)
        end
      end
    end

    context 'with a pays type de champ' do
      let(:procedure) do
        create(:procedure, types_de_champ_public: [{ type: :pays }]).tap do |p|
          p.groupe_instructeurs.create(label: 'a third group')
        end
      end

      let(:pays_tdc) { procedure.draft_revision.types_de_champ.first }

      context 'with a matching rule' do
        before do
          gi_2.update(routing_rule: ds_eq(champ_value(pays_tdc.stable_id), constant('BE')))
          dossier.champs.first.update_columns(
            value: "Belgique"
          )
        end

        it do
          is_expected.to eq(gi_2)
        end
      end
    end

    context 'routing rules priorities' do
      let(:procedure) do
        create(:procedure,
          types_de_champ_public: [{ type: :drop_down_list, libelle: 'Ville', options: ['Paris', 'Lyon', 'Marseille'] }]).tap do |p|
          p.groupe_instructeurs.create(label: 'c')
        end
      end

      let(:drop_down_tdc) { procedure.draft_revision.types_de_champ.first }

      let!(:gi_3) { procedure.groupe_instructeurs.find_by(label: 'c') }

      context 'not eq rule coming first' do
        before do
          defaut_groupe.update(label: 'a')
          gi_2.update(label: 'b', routing_rule: ds_not_eq(champ_value(drop_down_tdc.stable_id), constant('Lyon')))
          gi_3.update(routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id), constant('Marseille')))
          dossier.champs.first.update(value: 'Marseille')
        end

        it 'computes by groups label order' do
          is_expected.to eq(gi_2)
        end
      end
    end

    context 'performance with many groupe instructeurs' do
      let(:procedure) do
        create(:procedure,
          types_de_champ_public: [{ type: :drop_down_list, libelle: 'Commune', options: ['Commune_0001'] }])
      end

      let(:drop_down_tdc) { procedure.draft_revision.types_de_champ.first }
      let!(:last_groupe) { procedure.groupe_instructeurs.create(label: 'last_groupe', valid_routing_rule: true) }

      before do
        base_time = Time.current
        procedure_id = procedure.id
        tdc_stable_id = drop_down_tdc.stable_id

        groupe_data = Array.new(4999).map.with_index do |_, i|
          commune_name = "Commune_#{format('%04d', i + 2)}"
          {
            label: commune_name,
            procedure_id: procedure_id,
            valid_routing_rule: true,
            unique_routing_rule: true,
            routing_rule: {
              "term" => "Logic::Eq",
              "left" => { "term" => "Logic::ChampValue", "stable_id" => tdc_stable_id },
              "right" => { "term" => "Logic::Constant", "value" => commune_name },
            },
            created_at: base_time,
            updated_at: base_time,
          }
        end

        GroupeInstructeur.insert_all(groupe_data)

        last_groupe.update(routing_rule: ds_eq(champ_value(drop_down_tdc.stable_id), constant('Commune_0001')))

        dossier.champs.first.update(value: 'Commune_0001')
      end

      it 'routes to last groupe instructeur quickly even with 5000 groupes' do
        expect(procedure.groupe_instructeurs.count).to eq(5001)

        start_time = Time.current
        RoutingEngine.compute(dossier)
        end_time = Time.current

        expect(dossier.groupe_instructeur).to eq(last_groupe)
        expect(end_time - start_time).to be < 1
      end
    end
  end
end
