# frozen_string_literal: true

describe RevisionComparisonConcern do
  # Builds a procedure with one public type de champ (`from`), applies `to`
  # to it in a new draft and returns the changes between the two revisions.
  def compare(type, from: {}, to: {})
    procedure = create(:procedure, public_type_de_champs: [{ type:, libelle: 'champ', **from }])
    new_draft = procedure.create_new_revision
    stable_id = procedure.active_revision.public_root_type_de_champs.first.stable_id
    type_de_champ = new_draft.find_and_ensure_exclusive_use(stable_id)
    yield type_de_champ if block_given?
    type_de_champ = type_de_champ.becomes_type(to[:type_champ]) if to[:type_champ].present?
    type_de_champ.update!(to)
    procedure.active_revision.compare_type_de_champs(new_draft.reload).map(&:to_h)
  end

  def update(attribute, from, to)
    a_hash_including(op: :update, attribute:, from:, to:)
  end

  def filename(name)
    name.nil? ? nil : an_object_having_attributes(to_s: name)
  end

  # Each row: [type, from attributes, to attributes, expected change]. Every
  # row must produce exactly that one change: the table also guards against
  # spurious diffs on untouched options.
  def expect_single_changes(rows)
    aggregate_failures do
      rows.each do |type, from, to, expected|
        expect(compare(type, from:, to:)).to contain_exactly(expected), "#{type} #{from} -> #{to}"
      end
    end
  end

  describe '#compare_type_de_champs' do
    it 'diffs the attributes common to every type de champ' do
      expect_single_changes([
        [:text, {}, { libelle: 'new' }, update(:libelle, 'champ', 'new')],
        [:text, { description: 'old' }, { description: 'new' }, update(:description, 'old', 'new')],
        [:text, { mandatory: false }, { mandatory: true }, update(:mandatory, false, true)],
        [:text, {}, { type_champ: :integer_number }, update(:type_champ, 'text', 'integer_number')],
      ])
    end

    it 'reads the options of the previous version as the new type' do
      expect(compare(:text, to: { type_champ: :drop_down_list, drop_down_options: ['a'] }))
        .to contain_exactly(update(:type_champ, 'text', 'drop_down_list'), update(:drop_down_options, [], ['a']))
    end

    it 'diffs textarea options' do
      expect_single_changes([
        [:textarea, {}, { character_limit: '400' }, update(:character_limit, nil, '400')],
        [:textarea, { character_limit: '400' }, { character_limit: '' }, update(:character_limit, '400', '')],
      ])
      expect(compare(:textarea, to: { character_limit: '' })).to be_empty
    end

    it 'diffs number options' do
      expect_single_changes([
        [:integer_number, { positive_number: '0' }, { positive_number: '1' }, update(:positive_number, false, true)],
        [:integer_number, { range_number: '0' }, { range_number: '1' }, update(:range_number, false, true)],
        [:integer_number, { range_number: '1', min_number: '1' }, { min_number: '2' }, update(:min_number, '1', '2')],
        [:decimal_number, { range_number: '1', max_number: '9' }, { max_number: '' }, update(:max_number, '9', '')],
      ])
    end

    it 'diffs date options' do
      expect_single_changes([
        [:date, { range_date: '0' }, { range_date: '1' }, update(:range_date, false, true)],
        [:date, { date_in_past: '0' }, { date_in_past: '1' }, update(:date_in_past, false, true)],
        [:date, { range_date: '1', start_date: '2024-01-01' }, { start_date: '2025-01-01' }, update(:start_date, '2024-01-01', '2025-01-01')],
        [:datetime, { range_date: '1', end_date: '2024-01-01' }, { end_date: '' }, update(:end_date, '2024-01-01', '')],
      ])
    end

    it 'diffs formatted options' do
      simple = { formatted_mode: 'simple', letters_accepted: '1', numbers_accepted: '1', special_characters_accepted: '1' }
      advanced = { formatted_mode: 'advanced', expression_reguliere: '[a-z]+', expression_reguliere_exemple_text: 'abc' }

      expect_single_changes([
        [:formatted, simple, { letters_accepted: '0' }, update(:letters_accepted, true, false)],
        [:formatted, simple, { numbers_accepted: '0' }, update(:numbers_accepted, true, false)],
        [:formatted, simple, { special_characters_accepted: '0' }, update(:special_characters_accepted, true, false)],
        [:formatted, simple, { min_character_length: '2' }, update(:min_character_length, nil, '2')],
        [:formatted, simple, { max_character_length: '9' }, update(:max_character_length, nil, '9')],
        [:formatted, simple, { formatted_mode: 'advanced' }, update(:formatted_mode, 'simple', 'advanced')],
        [:formatted, advanced, { expression_reguliere: '[a-c]+' }, update(:expression_reguliere, '[a-z]+', '[a-c]+')],
        [:formatted, advanced, { expression_reguliere_exemple_text: 'xyz' }, update(:expression_reguliere_exemple_text, 'abc', 'xyz')],
        [:formatted, advanced, { expression_reguliere_indications: 'lowercase' }, update(:expression_reguliere_indications, nil, 'lowercase')],
        [:formatted, advanced, { expression_reguliere_error_message: 'nope' }, update(:expression_reguliere_error_message, nil, 'nope')],
      ])
    end

    it 'reads boolean options through their predicate, whatever their stored shape' do
      expect(compare(:formatted, from: { letters_accepted: true }, to: { letters_accepted: '1' })).to be_empty
      expect(compare(:integer_number, from: { positive_number: '0' }, to: { positive_number: nil })).to be_empty
      expect(compare(:date, from: { birthdate: '1' }, to: { birthdate: nil })).to contain_exactly(update(:birthdate, true, false))
    end

    it 'diffs repetition options' do
      expect_single_changes([
        [:repetition, { limit_repetitions: '0' }, { limit_repetitions: '1' }, update(:limit_repetitions, false, true)],
        [:repetition, { limit_repetitions: '1', min_repetitions: '1' }, { min_repetitions: '2' }, update(:min_repetitions, '1', '2')],
        [:repetition, { limit_repetitions: '1', max_repetitions: '3' }, { max_repetitions: '4' }, update(:max_repetitions, '3', '4')],
      ])
    end

    it 'diffs drop-down list options' do
      expect_single_changes([
        [:drop_down_list, { options: ['a'] }, { drop_down_options: ['a', 'b'] }, update(:drop_down_options, ['a'], ['a', 'b'])],
        [:drop_down_list, { options: ['a'] }, { drop_down_other: '1' }, update(:drop_down_other, false, true)],
        [:multiple_drop_down_list, { options: ['a'] }, { drop_down_options: ['b'] }, update(:drop_down_options, ['a'], ['b'])],
        [:linked_drop_down_list, { options: ['--a--', 'b'] }, { drop_down_secondary_libelle: 'sub' }, update(:drop_down_secondary_libelle, nil, 'sub')],
        [:linked_drop_down_list, { options: ['--a--', 'b'] }, { drop_down_secondary_description: 'sub' }, update(:drop_down_secondary_description, nil, 'sub')],
      ])
    end

    context 'with an advanced drop-down list' do
      let(:referentiel_1) { create(:csv_referentiel, :with_items) }
      let(:referentiel_2) { create(:csv_referentiel, :with_items) }

      it 'compares the referentiel instead of the options' do
        expect(compare(:drop_down_list, from: { drop_down_mode: 'advanced', referentiel: referentiel_1 }, to: { referentiel: referentiel_2 }))
          .to contain_exactly(update(:referentiel, referentiel_1.id, referentiel_2.id))
      end

      it 'reports the switch from simple to advanced' do
        expect(compare(:drop_down_list, from: { options: ['a'] }, to: { drop_down_mode: 'advanced', referentiel: referentiel_1 }))
          .to contain_exactly(update(:drop_down_mode, nil, 'advanced'), update(:referentiel, nil, referentiel_1.id), update(:drop_down_options, ['a'], []))
      end
    end

    it 'diffs the enabled carte layers as one change' do
      expect(compare(:carte, to: { options: { unesco: '1', znieff: '1' } })).to contain_exactly(update(:carte_layers, [], [:unesco, :znieff]))
    end

    it 'diffs piece justificative options' do
      expect_single_changes([
        [:piece_justificative, {}, { nature: 'rib' }, update(:nature, nil, 'rib')],
        [:piece_justificative, { pj_limit_formats: '0' }, { pj_limit_formats: '1' }, update(:pj_limit_formats, false, true)],
        [:piece_justificative, { pj_limit_formats: '1' }, { pj_format_families: ['image'] }, update(:pj_format_families, [], ['image'])],
        [:piece_justificative, { pj_auto_purge: '0' }, { pj_auto_purge: '1' }, update(:pj_auto_purge, false, true)],
      ])
    end

    it 'ignores the format options of the natures that force them' do
      expect(compare(:piece_justificative, from: { nature: 'rib' }, to: { pj_auto_purge: '1' })).to be_empty
    end

    it 'compares attachments by content and reports their filename' do
      attach = -> (attachment, name) { attachment.attach(io: StringIO.new(name), filename: name, content_type: 'text/plain', metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }) }

      template_changes = compare(:piece_justificative) { attach.call(it.piece_justificative_template, 'tata.txt') }
      notice_changes = compare(:explication) { attach.call(it.notice_explicative, 'notice.txt') }

      expect(template_changes).to contain_exactly(update(:piece_justificative_template, filename('toto.txt'), filename('tata.txt')))
      expect(notice_changes).to contain_exactly(update(:notice_explicative, nil, filename('notice.txt')))
    end

    it 'diffs explication options' do
      expect_single_changes([
        [:explication, {}, { collapsible_explanation_enabled: '1' }, update(:collapsible_explanation_enabled, false, true)],
        [:explication, { collapsible_explanation_enabled: '1' }, { collapsible_explanation_text: 'more' }, update(:collapsible_explanation_text, nil, 'more')],
      ])
    end

    it 'diffs referentiel and dossier link options' do
      referentiel = create(:api_referentiel, :exact_match)

      expect_single_changes([
        [:referentiel, { referentiel:, referentiel_mapping: { a: 1 } }, { referentiel_mapping: { a: 2 } }, update(:referentiel_mapping, { 'a' => 1 }, { 'a' => 2 })],
        [:dossier_link, { procedures_limit: '0' }, { procedures_limit: '1' }, update(:procedures_limit, false, true)],
      ])
    end

    it 'diffs header section, birthdate and pre rempli options' do
      expect_single_changes([
        [:header_section, { level: '1' }, { header_section_level: '2' }, update(:header_section_level, '1', '2')],
        [:date, { birthdate: '0' }, { birthdate: '1' }, update(:birthdate, false, true)],
        [:date, { birthdate: '1', prefill_with_france_connect_information: '0' }, { prefill_with_france_connect_information: '1' }, update(:prefill_with_france_connect_information, false, true)],
        [:pre_rempli, {}, { pre_rempli_hidden: '1' }, update(:pre_rempli_hidden, false, true)],
        [:pre_rempli, {}, { drop_down_options: ['a'] }, update(:drop_down_options, [], ['a'])],
      ])
    end
  end

  describe 'TypeDeChamp#revision_diff_attributes' do
    # Editable options that are, on purpose, not diffed one by one.
    let(:not_diffed) do
      {
        carte: TypesDeChamp::CarteTypeDeChamp::LAYERS, # aggregated as :carte_layers
        piece_justificative: [:old_pj, :skip_pj_validation, :skip_content_type_pj_validation], # legacy, not editable
      }
    end

    it 'covers every editable option of every type de champ' do
      aggregate_failures do
        TypeDeChamp.type_champs.each_key do |type_champ|
          klass = TypeDeChamp.find_sti_class(type_champ)
          diffed = klass.new.revision_diff_attributes(nil).keys
          expected = klass.option_keys - not_diffed.fetch(type_champ.to_sym, [])

          expect(expected - diffed).to be_empty, "#{type_champ} does not diff #{expected - diffed}"
        end
      end
    end
  end

  describe '#compare_type_de_champs between two revisions' do
    let(:draft) { procedure.draft_revision }
    include Logic
    let(:new_draft) { procedure.create_new_revision }
    subject { procedure.active_revision.compare_type_de_champs(new_draft.reload).map(&:to_h) }

    describe 'when tdcs changes' do
      let(:first_tdc) { draft.public_root_type_de_champs.first }
      let(:second_tdc) { draft.public_root_type_de_champs.second }

      context 'with a procedure with 2 tdcs' do
        let(:procedure) do
          create(:procedure, public_type_de_champs: [
            { type: :integer_number, libelle: 'l1' },
            { type: :text, libelle: 'l2' },
          ])
        end

        context 'when a condition is added' do
          before do
            second = new_draft.find_and_ensure_exclusive_use(second_tdc.stable_id)
            second.update(condition: ds_eq(champ_value(first_tdc.stable_id), constant(3)))
          end

          it do
            is_expected.to eq([
              {
                attribute: :condition,
                from: nil,
                label: "l2",
                op: :update,
                private: false,
                stable_id: second_tdc.stable_id,
                to: "(l1 == 3)",
              },
            ])
          end
        end

        context 'when a condition is removed' do
          before do
            second_tdc.update(condition: ds_eq(champ_value(first_tdc.stable_id), constant(2)))
            draft.reload

            second = new_draft.find_and_ensure_exclusive_use(second_tdc.stable_id)
            second.update(condition: nil)
          end

          it do
            is_expected.to eq([
              {
                attribute: :condition,
                from: "(l1 == 2)",
                label: "l2",
                op: :update,
                private: false,
                stable_id: second_tdc.stable_id,
                to: nil,
              },
            ])
          end
        end

        context 'when a condition is changed' do
          before do
            second_tdc.update(condition: ds_eq(champ_value(first_tdc.stable_id), constant(2)))
            draft.reload

            second = new_draft.find_and_ensure_exclusive_use(second_tdc.stable_id)
            second.update(condition: ds_eq(champ_value(first_tdc.stable_id), constant(3)))
          end

          it do
            is_expected.to eq([
              {
                attribute: :condition,
                from: "(l1 == 2)",
                label: "l2",
                op: :update,
                private: false,
                stable_id: second_tdc.stable_id,
                to: "(l1 == 3)",
              },
            ])
          end
        end
      end

      context 'when a type de champ is added' do
        let(:procedure) { create(:procedure) }
        let(:new_tdc) do
          new_draft.add_type_de_champ(
            type_champ: TypeDeChamp.type_champs.fetch(:text),
            mandatory: false,
            libelle: "Un champ text"
          )
        end

        before { new_tdc }

        it do
          is_expected.to eq([
            {
              op: :add,
              label: "Un champ text",
              private: false,
              mandatory: false,
              stable_id: new_tdc.stable_id,
            },
          ])
        end
      end

      context 'when a type de champ is changed' do
        context 'when libelle, description, and mandatory are changed' do
          let(:procedure) { create(:procedure, :with_type_de_champ) }

          before do
            updated_tdc = new_draft.find_and_ensure_exclusive_use(first_tdc.stable_id)

            updated_tdc.update(libelle: 'modifier le libelle', description: 'une description', mandatory: !updated_tdc.mandatory)
          end

          it do
            is_expected.to eq([
              {
                op: :update,
                attribute: :libelle,
                label: first_tdc.libelle,
                private: false,
                from: first_tdc.libelle,
                to: "modifier le libelle",
                stable_id: first_tdc.stable_id,
              },
              {
                op: :update,
                attribute: :description,
                label: first_tdc.libelle,
                private: false,
                from: first_tdc.description,
                to: "une description",
                stable_id: first_tdc.stable_id,
              },
              {
                op: :update,
                attribute: :mandatory,
                label: first_tdc.libelle,
                private: false,
                from: true,
                to: false,
                stable_id: first_tdc.stable_id,
              },
            ])
          end
        end

        context 'when collapsible_explanation_enabled and collapsible_explanation_text are changed' do
          let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :explication }]) }

          before do
            updated_tdc = new_draft.find_and_ensure_exclusive_use(first_tdc.stable_id)

            updated_tdc.update(collapsible_explanation_enabled: "1", collapsible_explanation_text: 'afficher au clique')
          end
          it do
            is_expected.to eq([
              {
                op: :update,
                attribute: :collapsible_explanation_enabled,
                label: first_tdc.libelle,
                private: first_tdc.private?,
                from: false,
                to: true,
                stable_id: first_tdc.stable_id,
              },
              {
                op: :update,
                attribute: :collapsible_explanation_text,
                label: first_tdc.libelle,
                private: first_tdc.private?,
                from: nil,
                to: 'afficher au clique',
                stable_id: first_tdc.stable_id,
              },
            ])
          end
        end
      end

      context 'when a type de champ is transformed into a text_area with no character limit' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }]) }

        before do
          updated_tdc = new_draft.find_and_ensure_exclusive_use(first_tdc.stable_id)
          updated_tdc.update(type_champ: :textarea, options: { "character_limit" => "" })
        end

        it do
          is_expected.to eq([
            {
              op: :update,
              attribute: :type_champ,
              label: first_tdc.libelle,
              private: false,
              from: "text",
              to: "textarea",
              stable_id: first_tdc.stable_id,
            },
          ])
        end
      end

      context 'when a type de champ is moved' do
        let(:procedure) { create(:procedure, public_type_de_champs: Array.new(3) { { type: :text } }) }
        let(:new_draft_second_tdc) { new_draft.public_root_type_de_champs.second }
        let(:new_draft_third_tdc) { new_draft.public_root_type_de_champs.third }

        before do
          new_draft_second_tdc
          new_draft_third_tdc
          new_draft.move_type_de_champ(new_draft_second_tdc.stable_id, 2)
        end

        it do
          is_expected.to eq([
            {
              op: :move,
              label: new_draft_third_tdc.libelle,
              private: false,
              from: 2,
              to: 1,
              stable_id: new_draft_third_tdc.stable_id,
            },
            {
              op: :move,
              label: new_draft_second_tdc.libelle,
              private: false,
              from: 1,
              to: 2,
              stable_id: new_draft_second_tdc.stable_id,
            },
          ])
        end
      end

      context 'when a type de champ is moved within a repetition' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text }, { type: :text }, { type: :repetition, children: [{ type: :text, libelle: 'first' }, { type: :text, libelle: 'second' }] }]) }
        let(:first_child) { new_draft.public_root_type_de_champs.last.children.first }

        before { new_draft.move_type_de_champ(first_child.stable_id, 1) }

        it 'counts positions among the content of the repetition' do
          is_expected.to contain_exactly(
            a_hash_including(op: :move, label: 'second', from: 1, to: 0),
            a_hash_including(op: :move, label: 'first', from: 0, to: 1)
          )
        end
      end

      context 'when a type de champ is moved out of a header section' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :text, libelle: 'before' }, { type: :header_section, libelle: 'section' }, { type: :text, libelle: 'within' }]) }
        let(:within) { new_draft.public_root_type_de_champs.last }

        before { new_draft.move_type_de_champ(within.stable_id, 0) }

        it 'counts positions across header sections' do
          is_expected.to contain_exactly(
            a_hash_including(op: :move, label: 'within', from: 2, to: 0),
            a_hash_including(op: :move, label: 'before', from: 0, to: 1),
            a_hash_including(op: :move, label: 'section', from: 1, to: 2)
          )
        end
      end

      context 'when a type de champ is removed' do
        let(:procedure) { create(:procedure, :with_type_de_champ) }

        before do
          new_draft.remove_type_de_champ(first_tdc.stable_id)
        end

        it do
          is_expected.to eq([
            {
              op: :remove,
              label: first_tdc.libelle,
              private: false,
              stable_id: first_tdc.stable_id,
            },
          ])
        end
      end

      context 'when a child type de champ is transformed into a drop_down_list' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, children: [{ type: :text, libelle: 'sub type de champ' }, { type: :integer_number }] }]) }

        before do
          child = new_draft.children_of(new_draft.public_root_type_de_champs.last).first
          new_draft.find_and_ensure_exclusive_use(child.stable_id).becomes_type('drop_down_list').update(type_champ: :drop_down_list, drop_down_options: ['one', 'two'])
        end

        it do
          is_expected.to eq([
            {
              op: :update,
              attribute: :type_champ,
              label: "sub type de champ",
              private: false,
              from: "text",
              to: "drop_down_list",
              stable_id: new_draft.children_of(new_draft.public_root_type_de_champs.last).first.stable_id,
            },
            {
              op: :update,
              attribute: :drop_down_options,
              label: "sub type de champ",
              private: false,
              from: [],
              to: ["one", "two"],
              stable_id: new_draft.children_of(new_draft.public_root_type_de_champs.last).first.stable_id,
            },
          ])
        end
      end

      context 'when a child type de champ is transformed into a map' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, children: [{ type: :text, libelle: 'sub type de champ' }, { type: :integer_number }] }]) }

        before do
          child = new_draft.children_of(new_draft.public_root_type_de_champs.last).first
          new_draft.find_and_ensure_exclusive_use(child.stable_id).update(type_champ: :carte, options: { cadastres: true, znieff: true })
        end

        it do
          is_expected.to eq([
            {
              op: :update,
              attribute: :type_champ,
              label: "sub type de champ",
              private: false,
              from: "text",
              to: "carte",
              stable_id: new_draft.children_of(new_draft.public_root_type_de_champs.last).first.stable_id,
            },
            {
              op: :update,
              attribute: :carte_layers,
              label: "sub type de champ",
              private: false,
              from: [],
              to: [:cadastres, :znieff],
              stable_id: new_draft.children_of(new_draft.public_root_type_de_champs.last).first.stable_id,
            },
          ])
        end
      end

      describe '#compare_referentiel_changes' do
        let(:procedure) { create(:procedure, public_type_de_champs:) }
        let(:referentiel_1) do
          create(
            :api_referentiel,
            :exact_match,
            name: SecureRandom.uuid,
            hint: 'Saisissez le code de votre reference'
          )
        end
        let(:referentiel_2) do
          create(
            :api_referentiel,
            :autocomplete,
            name: SecureRandom.uuid,
            hint: 'Saisissez le code de votre autre reference'
          )
        end
        let(:public_type_de_champs) do
          [
            {
              type: :referentiel,
              referentiel: referentiel_1,
              referentiel_mapping: { key: 'value1' },
              stable_id: 123,
              libelle: 'libelle',
            },
          ]
        end

        before do
          updated_tdc = new_draft.find_and_ensure_exclusive_use(first_tdc.stable_id)
          updated_tdc.update(referentiel: referentiel_2, referentiel_mapping: { key: 'value2' })
        end

        it 'detects changes in referentiel fields' do
          is_expected.to include({
            :attribute => :referentiel_url_tiptap,
            :from => "https://rnb-api.beta.gouv.fr/api/alpha/buildings/{Valeur saisie par l'usager}/",
            :label => "libelle",
            :op => :update,
            :private => false,
            :stable_id => 123,
            :to => "https://tabular-api.data.gouv.fr?finess__contains={Valeur saisie par l'usager}",
          })
          is_expected.to include({
            :attribute => :referentiel_mode,
            :from => "exact_match",
            :label => "libelle",
            :op => :update,
            :private => false,
            :stable_id => 123,
            :to => "autocomplete",
          })
          is_expected.to include({
            :attribute => :referentiel_hint,
            :from => 'Saisissez le code de votre reference',
            :label => "libelle",
            :op => :update,
            :private => false,
            :stable_id => 123,
            :to => 'Saisissez le code de votre autre reference',
          })
          is_expected.to include({
            :attribute => :referentiel_test_data_tiptap,
            :from => referentiel_1.test_data_tiptap.values.join(", "),
            :label => "libelle",
            :op => :update,
            :private => false,
            :stable_id => 123,
            :to => referentiel_2.test_data_tiptap.values.join(", "),
          })
          is_expected.to include({
            :attribute => :referentiel_mapping,
            :from => { "key" => "value1" },
            :label => "libelle",
            :op => :update,
            :private => false,
            :stable_id => 123,
            :to => { "key" => "value2" },
          })
        end
      end

      context 'when a dossier_link type de champ has procedures_limit and procedure_ids changed' do
        let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link, libelle: 'Dossier lié' }]) }

        context 'when procedures_limit is enabled' do
          before do
            updated_tdc = new_draft.find_and_ensure_exclusive_use(first_tdc.stable_id)
            updated_tdc.update(procedures_limit: "1")
          end

          it do
            is_expected.to eq([
              {
                op: :update,
                attribute: :procedures_limit,
                label: "Dossier lié",
                private: false,
                stable_id: first_tdc.stable_id,
                from: false,
                to: true,
              },
            ])
          end
        end

        context 'when dossier_link_procedure_ids are changed' do
          let!(:proc_a) { create(:procedure, libelle: "Démarche A") }
          let!(:proc_b) { create(:procedure, libelle: "Démarche B") }

          before do
            updated_tdc = new_draft.find_and_ensure_exclusive_use(first_tdc.stable_id)
            updated_tdc.update(dossier_link_procedure_ids: [proc_a.id, proc_b.id])
          end

          it do
            is_expected.to eq([
              {
                op: :update,
                attribute: :dossier_link_procedure_ids,
                label: "Dossier lié",
                private: false,
                stable_id: first_tdc.stable_id,
                from: [],
                to: [{ id: proc_a.id, libelle: "Démarche A" }, { id: proc_b.id, libelle: "Démarche B" }],
              },
            ])
          end
        end
      end
    end

    context 'when repetition limits are changed' do
      let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :repetition, libelle: 'bloc' }]) }
      let(:repetition_tdc) { draft.public_root_type_de_champs.first }

      before do
        updated_tdc = new_draft.find_and_ensure_exclusive_use(repetition_tdc.stable_id)
        updated_tdc.update(limit_repetitions: "1", min_repetitions: "2", max_repetitions: "5")
      end

      it do
        is_expected.to eq([
          {
            op: :update,
            attribute: :limit_repetitions,
            label: "bloc",
            private: false,
            from: false,
            to: true,
            stable_id: repetition_tdc.stable_id,
          },
          {
            op: :update,
            attribute: :min_repetitions,
            label: "bloc",
            private: false,
            from: nil,
            to: "2",
            stable_id: repetition_tdc.stable_id,
          },
          {
            op: :update,
            attribute: :max_repetitions,
            label: "bloc",
            private: false,
            from: nil,
            to: "5",
            stable_id: repetition_tdc.stable_id,
          },
        ])
      end
    end
  end

  describe 'compare_ineligibilite_rules' do
    include Logic
    let(:new_draft) { procedure.create_new_revision }
    subject { procedure.active_revision.compare_ineligibilite_rules(new_draft.reload) }

    context 'when ineligibilite_rules changes' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs:) }
      let(:public_type_de_champs) { [{ type: :yes_no }] }
      let(:yes_no_tdc) { new_draft.public_root_type_de_champs.first }

      context 'when nothing changed' do
        it { is_expected.to be_empty }
      end

      context 'when ineligibilite_rules added' do
        before do
          new_draft.update!(ineligibilite_rules: ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))
        end

        it { is_expected.to contain_exactly(an_instance_of(ProcedureRevisionChange::AddEligibiliteRuleChange)) }
      end

      context 'when ineligibilite_rules removed' do
        before do
          procedure.published_revision.update!(ineligibilite_rules: ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))
        end

        it { is_expected.to contain_exactly(an_instance_of(ProcedureRevisionChange::RemoveEligibiliteRuleChange)) }
      end

      context 'when ineligibilite_rules changed' do
        before do
          procedure.published_revision.update!(ineligibilite_rules: ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)))
          new_draft.update!(ineligibilite_rules: ds_and([
            ds_eq(champ_value(yes_no_tdc.stable_id), constant(true)),
            empty_operator(empty, empty),
          ]))
        end

        it { is_expected.to contain_exactly(an_instance_of(ProcedureRevisionChange::UpdateEligibiliteRuleChange)) }
      end

      context 'when when ineligibilite_enabled changes from false to true' do
        before do
          procedure.published_revision.update!(ineligibilite_enabled: false, ineligibilite_message: :required)
          new_draft.update!(ineligibilite_enabled: true, ineligibilite_message: :required)
        end

        it { is_expected.to include(an_instance_of(ProcedureRevisionChange::EligibiliteEnabledChange)) }
      end

      context 'when ineligibilite_enabled changes from true to false' do
        before do
          procedure.published_revision.update!(ineligibilite_enabled: true, ineligibilite_message: :required)
          new_draft.update!(ineligibilite_enabled: false, ineligibilite_message: :required)
        end

        it { is_expected.to include(an_instance_of(ProcedureRevisionChange::EligibiliteDisabledChange)) }
      end

      context 'when ineligibilite_message changes' do
        before do
          procedure.published_revision.update!(ineligibilite_message: :a)
          new_draft.update!(ineligibilite_message: :b)
        end

        it { is_expected.to include(an_instance_of(ProcedureRevisionChange::UpdateEligibiliteMessageChange)) }
      end
    end
  end
end
