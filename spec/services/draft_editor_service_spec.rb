# frozen_string_literal: true

describe DraftEditorService do
  let(:public_type_de_champs) do
    [
      { libelle: 'nom' },
      { type: :integer_number, libelle: 'age' },
      { type: :drop_down_list, libelle: 'statut', options: ['salarié', 'étudiant'] },
      { type: :repetition, libelle: 'enfants', children: [{ libelle: 'prénom' }, { type: :date, libelle: 'naissance' }] },
      { type: :yes_no, libelle: 'boursier' },
    ]
  end
  let(:private_type_de_champs) { [{ libelle: 'avis' }] }
  let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }
  let(:draft) { procedure.draft_revision }
  let(:service) { described_class.new(procedure) }

  def tdc(libelle) = procedure.draft_revision.reload.type_de_champs.find { it.libelle == libelle }
  def sid(libelle) = tdc(libelle).stable_id.to_s
  def public_libelles = procedure.draft_revision.reload.public_root_type_de_champs.map(&:libelle)

  def children_libelles(libelle) = tdc(libelle).flat_children.map(&:libelle)

  describe '#describe' do
    subject(:description) { service.describe }

    def champ(libelle) = description[:champs].find { it[:libelle] == libelle }

    it 'describes the form and the annotations apart, each in its order' do
      expect(description.keys).to eq([:champs, :annotations])
      expect(description[:champs].map { it[:libelle] }).to eq(['nom', 'age', 'statut', 'enfants', 'boursier'])
      expect(description[:annotations].map { it[:libelle] }).to eq(['avis'])
    end

    it 'describes a type de champ' do
      expect(champ('statut')).to eq(
        stable_id: sid('statut'),
        type_champ: 'drop_down_list',
        libelle: 'statut',
        description: tdc('statut').description,
        mandatory: true,
        options: tdc('statut').clean_options
      )
      expect(champ('statut')[:options]).to include('drop_down_options' => ['salarié', 'étudiant'])
    end

    it 'describes the children of a repetition under it' do
      expect(champ('enfants')[:champs].map { it[:libelle] }).to eq(['prénom', 'naissance'])
      expect(champ('enfants')[:champs].first).to include(stable_id: sid('prénom'), type_champ: 'text')
      expect(champ('nom')).not_to have_key(:champs)
    end

    it 'describes an empty repetition as one' do
      service.add(type_champ: 'repetition', libelle: 'diplômes')

      expect(service.describe[:champs].find { it[:libelle] == 'diplômes' }[:champs]).to eq([])
    end

    it 'leaves the header sections among their siblings' do
      service.add(type_champ: 'header_section', libelle: 'identité')

      expect(service.describe[:champs].map { it[:libelle] }.take(2)).to eq(['identité', 'nom'])
    end

    it 'reads a condition in the format set_condition takes' do
      terms = [
        { source_stable_id: sid('age'), operator: 'greater_than_eq', value: '18' },
        { source_stable_id: sid('statut'), operator: 'eq', value: 'étudiant' },
      ]
      expect(service.set_condition(sid('boursier'), operator: 'or', terms:)).to be_success

      condition = champ('boursier')[:condition]
      expect(condition[:operator]).to eq('or')
      expect(condition[:terms].map { it.except(:source_libelle) }).to eq(terms)
      expect(condition[:terms].map { it[:source_libelle] }).to eq(['age', 'statut'])

      # what is read can be sent back as it is
      expect(service.set_condition(sid('boursier'), **condition)).to be_success
      expect(tdc('boursier').condition).to eq(Logic::Or.new([
        Logic::GreaterThanEq.new(Logic::ChampValue.new(tdc('age').stable_id), Logic::Constant.new(18)),
        Logic::Eq.new(Logic::ChampValue.new(tdc('statut').stable_id), Logic::Constant.new('étudiant')),
      ]))
    end
  end

  describe '#add' do
    it 'adds first in the form without a position' do
      result = service.add(type_champ: 'email', libelle: 'courriel', mandatory: true)

      expect(result).to be_success
      expect(result.stable_id).to eq(sid('courriel'))
      expect(public_libelles.first).to eq('courriel')
      expect(tdc('courriel')).to be_mandatory
    end

    it 'adds after another type de champ' do
      service.add(type_champ: 'text', libelle: 'prénom usager', after_stable_id: sid('nom'))

      expect(public_libelles.take(3)).to eq(['nom', 'prénom usager', 'age'])
    end

    it 'adds in a repetition' do
      result = service.add(type_champ: 'text', libelle: 'école', parent_stable_id: sid('enfants'), after_stable_id: sid('prénom'))

      expect(result).to be_success
      expect(children_libelles('enfants')).to eq(['prénom', 'école', 'naissance'])
    end

    it 'adds a private type de champ' do
      result = service.add(type_champ: 'text', libelle: 'décision', private: true, after_stable_id: sid('avis'))

      expect(result).to be_success
      expect(tdc('décision')).to be_private
    end

    it 'sets the options of the type' do
      result = service.add(type_champ: 'drop_down_list', libelle: 'couleur', options: { drop_down_options: ['rouge', ' vert '], drop_down_other: true })

      expect(result).to be_success
      expect(tdc('couleur').drop_down_options).to eq(['rouge', 'vert'])
      expect(tdc('couleur')).to be_drop_down_other
    end

    it 'keeps every layer of a carte' do
      service.add(type_champ: 'carte', libelle: 'parcelle', options: { cadastres: true, unesco: true, znieff: true })

      expect(tdc('parcelle').carte_optional_layers).to eq([:cadastres, :unesco, :znieff])

      service.update(sid('parcelle'), options: { natura_2000: true })
      expect(tdc('parcelle').carte_optional_layers).to eq([:cadastres, :natura_2000, :unesco, :znieff])
    end

    it 'refuses a header section level that does not exist' do
      result = service.add(type_champ: 'header_section', libelle: 'titre', options: { header_section_level: '9' })

      expect(result.errors.first).to include('« 9 »').and include('de 1 à 3')
      expect(tdc('titre')).to be_nil
      expect(service.add(type_champ: 'header_section', libelle: 'titre', options: { header_section_level: 2 })).to be_success
    end

    it 'refuses a type that is not enabled on the procedure' do
      expect(service.add(type_champ: 'engagement_juridique', libelle: 'ej', private: true).errors.first).to include('n’est pas activé')
    end

    it 'refuses an unknown type' do
      result = service.add(type_champ: 'formule', libelle: 'total')

      expect(result).not_to be_success
      expect(result.errors).to eq(["Le type de champ « formule » n’existe pas."])
    end

    it 'refuses the options of another type, naming the ones it accepts' do
      result = service.add(type_champ: 'textarea', libelle: 'motivation', options: { max_number: 3 })

      expect(result.errors.first).to include('max_number').and include('character_limit')
      expect(tdc('motivation')).to be_nil
    end

    it 'refuses an internal option' do
      result = service.add(type_champ: 'piece_justificative', libelle: 'rib', options: { skip_pj_validation: true })

      expect(result.errors.first).to include('skip_pj_validation')
    end

    it 'refuses a parent that is not a repetition' do
      result = service.add(type_champ: 'text', libelle: 'x', parent_stable_id: sid('nom'))

      expect(result.errors.first).to include('n’est pas une répétition')
    end

    it 'refuses a repetition in a repetition' do
      result = service.add(type_champ: 'repetition', libelle: 'x', parent_stable_id: sid('enfants'))

      expect(result.errors.first).to include('dans une répétition')
    end

    it 'refuses a position in another block' do
      expect(service.add(type_champ: 'text', libelle: 'x', after_stable_id: sid('prénom')).errors.first).to include('même bloc')
      expect(service.add(type_champ: 'text', libelle: 'x', after_stable_id: sid('avis')).errors.first).to include('même bloc')
      expect(service.add(type_champ: 'text', libelle: 'x', after_stable_id: '42').errors.first).to include('n’existe pas')
    end
  end

  describe '#update' do
    it 'updates the libelle, the description and the mandatory flag' do
      result = service.update(sid('nom'), libelle: 'nom de famille', description: 'tel que sur la pièce d’identité', mandatory: false)

      expect(result).to be_success
      expect(tdc('nom de famille')).to have_attributes(description: 'tel que sur la pièce d’identité', mandatory: false)
    end

    it 'keeps the stable id' do
      stable_id = sid('nom')

      expect(service.update(stable_id, libelle: 'nom de famille').stable_id).to eq(stable_id)
      expect(sid('nom de famille')).to eq(stable_id)
    end

    it 'changes the type and sets the options of the new type at once' do
      result = service.update(sid('nom'), type_champ: 'textarea', options: { character_limit: '400' })

      expect(result).to be_success
      expect(tdc('nom')).to be_a(TypesDeChamp::TextareaTypeDeChamp)
      expect(tdc('nom').character_limit).to eq('400')
    end

    it 'updates an option without losing the others' do
      service.update(sid('age'), options: { min_number: '0', range_number: true })
      service.update(sid('age'), options: { max_number: '120' })

      expect(tdc('age')).to have_attributes(min_number: '0', max_number: '120')
    end

    it 'refuses the options of another type' do
      expect(service.update(sid('nom'), options: { character_limit: '400' }).errors.first).to include('character_limit')
    end

    context 'when a condition reads the type de champ' do
      before { service.set_condition(sid('avis'), terms: [{ source_stable_id: sid('boursier'), operator: 'eq', value: 'true' }, { source_stable_id: sid('statut'), operator: 'eq', value: 'étudiant' }]) }

      it 'refuses a type the condition cannot compare, and undoes the edit' do
        result = service.update(sid('boursier'), type_champ: 'text', libelle: 'bourse')

        expect(result.errors.first).to eq("Cette modification rendrait invalide la condition d’affichage de « avis » (#{sid('avis')}) : modifiez ou retirez d’abord cette condition.")
        expect(tdc('boursier')).to have_attributes(type_champ: 'yes_no')
        expect(tdc('bourse')).to be_nil
      end

      it 'refuses to drop the option the condition compares to' do
        expect(service.update(sid('statut'), options: { drop_down_options: ['salarié'] }).errors.first).to include('« avis »')
        expect(tdc('statut').drop_down_options).to eq(['salarié', 'étudiant'])
      end

      it 'accepts what leaves the condition valid' do
        expect(service.update(sid('boursier'), type_champ: 'checkbox', libelle: 'bourse')).to be_success
        expect(service.update(sid('statut'), options: { drop_down_options: ['salarié', 'étudiant', 'retraité'] })).to be_success
      end
    end

    it 'refuses to do nothing' do
      expect(service.update(sid('nom')).errors).to eq(["Aucune modification demandée."])
    end

    it 'refuses an unknown type de champ' do
      expect(service.update('42', libelle: 'x').errors.first).to include('n’existe pas')
    end

    context 'when the type de champ is used by a condition of ineligibilite' do
      before do
        draft.update!(ineligibilite_enabled: true, ineligibilite_message: 'non', ineligibilite_rules: Logic::Eq.new(Logic::ChampValue.new(tdc('boursier').stable_id), Logic::Constant.new(true)))
      end

      it 'refuses to change its type' do
        expect(service.update(sid('boursier'), type_champ: 'checkbox').errors.first).to include('inéligibilité')
        expect(service.update(sid('boursier'), libelle: 'élève boursier')).to be_success
      end
    end

    context 'on a published procedure' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs:, private_type_de_champs:) }

      it 'changes the type to one the filed dossiers remain readable in' do
        expect(service.update(sid('nom'), type_champ: 'textarea')).to be_success
        expect(procedure.published_revision.type_de_champs.find { it.libelle == 'nom' }.type_champ).to eq('text')
      end

      it 'refuses another type, naming the ones it accepts' do
        result = service.update(sid('naissance'), type_champ: 'yes_no')

        expect(result.errors.first).to include('déjà publié').and include('datetime')
        expect(tdc('naissance').type_champ).to eq('date')
      end

      it 'leaves the published revision as it is' do
        service.update(sid('nom'), libelle: 'nom de famille')

        expect(procedure.published_revision.type_de_champs.map(&:libelle)).to include('nom')
        expect(procedure.published_revision.type_de_champs.map(&:libelle)).not_to include('nom de famille')
      end
    end
  end

  describe '#move' do
    it 'moves after another type de champ, down or up' do
      expect(service.move(sid('nom'), after_stable_id: sid('statut'))).to be_success
      expect(public_libelles).to eq(['age', 'statut', 'nom', 'enfants', 'boursier'])

      expect(service.move(sid('boursier'), after_stable_id: sid('age'))).to be_success
      expect(public_libelles).to eq(['age', 'boursier', 'statut', 'nom', 'enfants'])
    end

    it 'moves first without a position' do
      expect(service.move(sid('boursier'))).to be_success
      expect(public_libelles.first).to eq('boursier')
    end

    it 'moves in a repetition' do
      expect(service.move(sid('prénom'), after_stable_id: sid('naissance'))).to be_success
      expect(children_libelles('enfants')).to eq(['naissance', 'prénom'])
    end

    context 'when a condition reads the type de champ' do
      before { service.set_condition(sid('statut'), terms: [{ source_stable_id: sid('age'), operator: 'less_than', value: '26' }]) }

      it 'refuses to move the source after the type de champ it conditions' do
        expect(service.move(sid('age'), after_stable_id: sid('statut')).errors.first).to include('« statut »')
        expect(public_libelles).to eq(['nom', 'age', 'statut', 'enfants', 'boursier'])
      end

      it 'refuses to move the type de champ before its source' do
        expect(service.move(sid('statut')).errors.first).to include('« statut »')
        expect(public_libelles).to eq(['nom', 'age', 'statut', 'enfants', 'boursier'])
      end

      it 'moves them as long as the source stays before' do
        expect(service.move(sid('statut'), after_stable_id: sid('boursier'))).to be_success
        expect(service.move(sid('age'))).to be_success
        expect(public_libelles).to eq(['age', 'nom', 'enfants', 'boursier', 'statut'])
      end
    end

    it 'refuses to move to another block or after itself' do
      expect(service.move(sid('nom'), after_stable_id: sid('prénom')).errors.first).to include('même bloc')
      expect(service.move(sid('nom'), after_stable_id: sid('avis')).errors.first).to include('même bloc')
      expect(service.move(sid('nom'), after_stable_id: sid('nom')).errors.first).to include('lui-même')
      expect(service.move('42').errors.first).to include('n’existe pas')
    end
  end

  describe '#remove' do
    it 'removes a type de champ' do
      expect(service.remove(sid('nom'))).to be_success
      expect(public_libelles).to eq(['age', 'statut', 'enfants', 'boursier'])
    end

    it 'removes a repetition with its children' do
      expect(service.remove(sid('enfants'))).to be_success
      expect(tdc('prénom')).to be_nil
    end

    it 'refuses to remove the source of a condition' do
      service.set_condition(sid('boursier'), terms: [{ source_stable_id: sid('age'), operator: 'less_than', value: '26' }])

      result = service.remove(sid('age'))

      expect(result.errors.first).to include('condition d’affichage').and include('boursier')
      expect(public_libelles).to include('age')
    end

    it 'refuses an unknown type de champ' do
      expect(service.remove('42').errors.first).to include('n’existe pas')
    end
  end

  describe '#set_condition' do
    it 'sets a condition of one term' do
      result = service.set_condition(sid('boursier'), terms: [{ source_stable_id: sid('statut'), operator: 'eq', value: 'étudiant' }])

      expect(result).to be_success
      expect(tdc('boursier').condition).to eq(Logic::Eq.new(Logic::ChampValue.new(tdc('statut').stable_id), Logic::Constant.new('étudiant')))
    end

    it 'reads the value as the type of the source compares it' do
      service.set_condition(sid('avis'), terms: [{ source_stable_id: sid('boursier'), operator: 'eq', value: 'true' }])

      expect(tdc('avis').condition.right).to eq(Logic::Constant.new(true))
    end

    it 'refuses a value that is neither true nor false on a yes/no' do
      result = service.set_condition(sid('avis'), terms: [{ source_stable_id: sid('boursier'), operator: 'not_eq', value: 'Défavorable' }])

      expect(result.errors.first).to include('boursier')
      expect(tdc('avis').condition).to be_nil
    end

    it 'says why the child of a repetition cannot be read from outside' do
      result = service.set_condition(sid('boursier'), terms: [{ source_stable_id: sid('prénom'), operator: 'eq', value: 'x' }])

      expect(result.errors.first).to eq("« prénom » (#{sid('prénom')}) est dans la répétition « enfants » : il ne peut conditionner que des champs de cette répétition.")
    end

    it 'takes terms with string keys' do
      result = service.set_condition(sid('boursier'), terms: [{ 'source_stable_id' => sid('age'), 'operator' => 'less_than', 'value' => '26' }])

      expect(result).to be_success
    end

    it 'removes the condition without a term' do
      service.set_condition(sid('boursier'), terms: [{ source_stable_id: sid('age'), operator: 'less_than', value: '26' }])

      expect(service.set_condition(sid('boursier'), terms: [])).to be_success
      expect(tdc('boursier').condition).to be_nil
    end

    it 'refuses a source placed after the type de champ' do
      result = service.set_condition(sid('nom'), terms: [{ source_stable_id: sid('age'), operator: 'less_than', value: '26' }])

      expect(result.errors.first).to eq("« age » (#{sid('age')}) ne peut pas être la source de cette condition : la source doit être placée avant « nom ».")
      expect(tdc('nom').condition).to be_nil
    end

    it 'refuses an unknown operator, naming the ones it accepts' do
      result = service.set_condition(sid('boursier'), terms: [{ source_stable_id: sid('age'), operator: 'lt', value: '26' }])

      expect(result.errors.first).to include('« lt »').and include('less_than')
      expect(service.set_condition(sid('boursier'), operator: 'xor', terms: []).errors.first).to include('« xor »')
    end

    it 'refuses a value the source does not offer, worded as the editor does' do
      result = service.set_condition(sid('boursier'), terms: [{ source_stable_id: sid('statut'), operator: 'eq', value: 'retraité' }])

      expect(result.errors).to be_present
      expect(result.errors.first).to include('statut')
      expect(tdc('boursier').condition).to be_nil
    end

    it 'refuses a source that cannot be compared' do
      result = service.set_condition(sid('boursier'), terms: [{ source_stable_id: sid('nom'), operator: 'eq', value: 'x' }])

      expect(result.errors.first).to include('nom')
    end

    it 'refuses a condition that can never be true' do
      terms = [
        { source_stable_id: sid('age'), operator: 'less_than', value: '10' },
        { source_stable_id: sid('age'), operator: 'greater_than', value: '20' },
      ]

      expect(service.set_condition(sid('boursier'), terms:).errors).to be_present
    end
  end

  describe '#type_champs' do
    subject(:types) { service.type_champs }

    it 'describes the types the procedure may use' do
      expect(types.find { it[:type_champ] == 'textarea' }).to include(libelle: 'Texte long', options: [:character_limit], allowed_in_repetition: true)
      expect(types.find { it[:type_champ] == 'yes_no' }).to include(condition_source: true)
      expect(types.map { it[:type_champ] }).not_to include('engagement_juridique')
      expect(types.map { it[:libelle] }.join).not_to include('ranslation missing')
    end

    context 'when a type under a feature flag is enabled' do
      before { Flipper.enable(:engagement_juridique_type_de_champ, procedure) }

      it { expect(types.map { it[:type_champ] }).to include('engagement_juridique') }
    end
  end

  describe '.option_keys' do
    it 'lists the options a client may set on a type' do
      expect(described_class.option_keys('textarea')).to eq([:character_limit])
      expect(described_class.option_keys('piece_justificative')).not_to include(:skip_pj_validation)
      expect(described_class.option_keys('referentiel')).to be_empty
    end
  end
end
