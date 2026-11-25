# frozen_string_literal: true

describe RevisionEditConcern do
  include Logic

  let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }
  let(:draft) { procedure.draft_revision }
  # a, s1 [b, s2 [c]], r [r1, r2], d
  let(:public_type_de_champs) do
    [
      { libelle: 'a' },
      { type: :header_section, libelle: 's1', children: [{ libelle: 'b' }, { type: :header_section, libelle: 's2', children: [{ libelle: 'c' }] }] },
      { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }, { libelle: 'r2' }] },
      { libelle: 'd' },
    ]
  end
  let(:private_type_de_champs) { [{ libelle: 'p' }] }

  def tdc(libelle) = draft.type_de_champs.find { it.libelle == libelle }
  def stable_id(libelle) = tdc(libelle).stable_id

  # a header section and a repetition with what they hold
  def layout(type_de_champs = draft.public_type_de_champs)
    type_de_champs.map { it.header_section? || it.repetition? ? { it.libelle => layout(it.children) } : it.libelle }
  end

  def refuse(message = nil) = raise_error(RevisionEditConcern::RefusedError, *message)

  describe '#edit_type_de_champs' do
    it 'writes the tree once, when the edit is done' do
      expect(draft).to receive(:write_type_de_champ_tree).once.and_call_original

      draft.edit_type_de_champs do
        draft.move_up_type_de_champ(stable_id('d'))
        draft.remove_type_de_champ(stable_id('a'))
      end

      expect(layout(ProcedureRevision.find(draft.id).public_type_de_champs)).to eq([{ 's1' => ['b', { 's2' => ['c'] }] }, 'd', { 'r' => ['r1', 'r2'] }])
    end

    it 'leaves the tree as it was when the edit is refused' do
      tree = draft.type_de_champ_tree

      expect do
        draft.edit_type_de_champs do
          draft.remove_type_de_champ(stable_id('a'))
          draft.move_type_de_champ(stable_id('d'), parent_stable_id: stable_id('r'))
        end
      end.to refuse

      expect(draft.type_de_champ_tree).to eq(tree)
      expect(draft).not_to be_changed
      expect(draft.reload.type_de_champ_tree).to eq(tree)
    end

    it 'edits a saved revision only, as the lock reloads it' do
      expect { ProcedureRevision.new.edit_type_de_champs { nil } }.to raise_error(ArgumentError)
    end

    it 'never edits a published revision' do
      procedure.publish_revision!(procedure.administrateurs.first)

      expect { procedure.published_revision.remove_type_de_champ(stable_id('a')) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#add_type_de_champ' do
    it 'adds first of the form, or of the annotations' do
      added = draft.add_type_de_champ(type_champ: 'text', libelle: 'new')

      expect(added).to equal(draft.type_de_champ(added.stable_id))
      expect(added.procedure).to eq(procedure)

      annotation = draft.add_type_de_champ(type_champ: 'text', libelle: 'new annotation', private: true)

      expect(layout.first).to eq('new')
      expect(layout(draft.private_type_de_champs)).to eq(['new annotation', 'p'])
      expect(annotation).not_to be_mandatory
    end

    it 'adds after a sibling, in what holds it' do
      draft.add_type_de_champ(type_champ: 'text', libelle: 'new', after_stable_id: stable_id('b'))
      draft.add_type_de_champ(type_champ: 'text', libelle: 'new row', after_stable_id: stable_id('r1'))
      annotation = draft.add_type_de_champ(type_champ: 'text', libelle: 'new annotation', after_stable_id: stable_id('p'))

      expect(layout).to eq(['a', { 's1' => ['b', 'new', { 's2' => ['c'] }] }, { 'r' => ['r1', 'new row', 'r2'] }, 'd'])
      expect(layout(draft.private_type_de_champs)).to eq(['p', 'new annotation'])
      expect(annotation).to be_private
    end

    it 'adds first of a header section or of a repetition' do
      draft.add_type_de_champ(type_champ: 'text', libelle: 'new', parent_stable_id: stable_id('s2'))
      draft.add_type_de_champ(type_champ: 'text', libelle: 'new row', parent_stable_id: stable_id('r'))

      expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['new', 'c'] }] }, { 'r' => ['new row', 'r1', 'r2'] }, 'd'])
    end

    it 'refuses what a block does not take, and adds nothing' do
      in_repetition = draft.add_type_de_champ(type_champ: 'repetition', libelle: 'new', parent_stable_id: stable_id('r'))
      in_a_champ = draft.add_type_de_champ(type_champ: 'text', libelle: 'new', parent_stable_id: stable_id('a'))
      too_deep = draft.add_type_de_champ(type_champ: 'header_section', libelle: 's3', parent_stable_id: stable_id('s2')).then do |s3|
        draft.add_type_de_champ(type_champ: 'header_section', libelle: 's4', parent_stable_id: s3.stable_id)
      end

      expect([in_repetition, in_a_champ, too_deep]).to all(be_new_record)
      expect(in_repetition.errors.full_messages.first).to include('bloc répétable')
      expect(too_deep.errors.full_messages.first).to include('3 niveaux')
      expect(procedure.type_de_champs.where(libelle: ['new', 's4'])).to be_empty
    end

    it 'refuses a type which does not exist' do
      added = draft.add_type_de_champ(type_champ: 'unknown', libelle: 'new')

      expect(added).to be_new_record
      expect(added.errors.full_messages).to eq(["Ce type de champ n’existe pas."])
    end

    it 'returns the type de champ which could not be saved' do
      added = draft.add_type_de_champ(libelle: 'new')

      expect(added).to be_new_record
      expect(added.errors).to be_present
    end

    it 'cannot add after a type de champ which is gone' do
      expect { draft.add_type_de_champ(type_champ: 'text', after_stable_id: -1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#find_and_ensure_exclusive_use' do
    it 'returns the type de champ of a draft never published' do
      expect(draft.find_and_ensure_exclusive_use(stable_id('a'))).to equal(tdc('a'))
    end

    it 'cannot find a type de champ which is gone' do
      expect { draft.find_and_ensure_exclusive_use(-1) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'on a published procedure' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs:, private_type_de_champs:) }

      it 'replaces a type de champ the published revision lays out by a copy, once' do
        published = procedure.published_revision.type_de_champ(stable_id('r'))

        copy = draft.find_and_ensure_exclusive_use(published.stable_id)

        expect(copy.id).not_to eq(published.id)
        expect(copy).to have_attributes(stable_id: published.stable_id, libelle: 'r', procedure:)
        expect(copy).to equal(draft.type_de_champ(published.stable_id))
        # with what it held
        expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }] }, { 'r' => ['r1', 'r2'] }, 'd'])
        expect(procedure.published_revision.reload.type_de_champ(published.stable_id).id).to eq(published.id)

        expect(draft.find_and_ensure_exclusive_use(published.stable_id).id).to eq(copy.id)
        expect(ProcedureRevision.find(draft.id).find_and_ensure_exclusive_use(published.stable_id).id).to eq(copy.id)
      end

      it 'returns a type de champ added to the draft' do
        added = draft.add_type_de_champ(type_champ: 'text', libelle: 'new')

        expect(draft.find_and_ensure_exclusive_use(added.stable_id).id).to eq(added.id)
      end
    end
  end

  describe '#update_type_de_champ' do
    it 'updates the type de champ the draft lays out' do
      updated = draft.update_type_de_champ(stable_id('a'), libelle: 'a bis', mandatory: false)

      expect(updated).to equal(draft.type_de_champ(updated.stable_id))
      expect(updated.reload).to have_attributes(libelle: 'a bis', mandatory: false)
    end

    it 'returns the type de champ which could not be saved, and leaves the tree alone' do
      tree = draft.type_de_champ_tree

      updated = draft.update_type_de_champ(stable_id('s1'), type_champ: 'textarea', character_limit: 'beaucoup')

      expect(updated.errors).to be_present
      # the draft lays it out as it is saved
      expect(tdc('s1')).to be_header_section
      expect(tdc('s1')).not_to be_changed
      expect(draft.reload.type_de_champ_tree).to eq(tree)
    end

    it 'drops the options of another type' do
      updated = draft.update_type_de_champ(stable_id('a'), libelle: 'a bis', drop_down_other: '1')

      expect(updated.errors).to be_empty
      expect(updated.libelle).to eq('a bis')
    end

    it 'cannot update a type de champ which is gone' do
      expect { draft.update_type_de_champ(-1, libelle: 'a bis') }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'when the type changes, on a type de champ not published yet' do
      it 'takes any type its block allows' do
        updated = draft.update_type_de_champ(stable_id('a'), type_champ: 'header_section')

        expect(updated).to be_a(TypesDeChamp::HeaderSectionTypeDeChamp)
        expect(updated).to equal(draft.type_de_champ(updated.stable_id))
        expect(layout.first).to eq({ 'a' => [] })

        expect { draft.update_type_de_champ(stable_id('r1'), type_champ: 'repetition') }.to refuse(/bloc répétable/)
        expect { draft.update_type_de_champ(stable_id('c'), type_champ: 'header_section') }.not_to raise_error
        expect { draft.update_type_de_champ(stable_id('c'), type_champ: 'text') }.not_to raise_error
        draft.add_type_de_champ(type_champ: 'header_section', libelle: 's3', parent_stable_id: stable_id('s2'))
        expect { draft.update_type_de_champ(stable_id('c'), type_champ: 'header_section') }.not_to raise_error
        expect { draft.update_type_de_champ(draft.add_type_de_champ(type_champ: 'text', libelle: 'deep', parent_stable_id: stable_id('s3')).stable_id, type_champ: 'header_section') }.to refuse(/3 niveaux/)
      end

      it 'leaves what a header section held in its place' do
        draft.update_type_de_champ(stable_id('s1'), type_champ: 'text')

        expect(layout).to eq(['a', 's1', 'b', { 's2' => ['c'] }, { 'r' => ['r1', 'r2'] }, 'd'])
      end

      it 'keeps the type of a repetition holding types de champ: they would leave the draft for good' do
        expect { draft.update_type_de_champ(stable_id('r'), type_champ: 'text') }.to refuse(I18n.t('activerecord.errors.type_de_champ.locked.update.repetition_holding_champs', type_de_champ: 'r'))
        expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }] }, { 'r' => ['r1', 'r2'] }, 'd'])

        ['r1', 'r2'].each { draft.remove_type_de_champ(stable_id(it)) }

        expect(draft.update_type_de_champ(stable_id('r'), type_champ: 'text')).to be_text
        expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }] }, 'r', 'd'])
      end

      it 'refuses a type de champ the routing reads' do
        allow_any_instance_of(Procedure).to receive(:used_by_routing_rules?) { |_, type_de_champ| type_de_champ.libelle == 'a' }

        expect { draft.update_type_de_champ(stable_id('a'), type_champ: 'textarea') }.to refuse('« a » est utilisé pour le routage, vous ne pouvez pas modifier son type.')
        expect(tdc('a')).to be_text
      end
    end

    context 'when the type changes, on a published type de champ' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs:, private_type_de_champs:) }

      it 'takes a type its published type converts to, and its published type again' do
        published = procedure.published_revision.type_de_champ(stable_id('a'))

        updated = draft.update_type_de_champ(published.stable_id, type_champ: 'textarea')

        expect(updated).to be_textarea
        expect(updated.id).not_to eq(published.id)
        expect(published.reload).to be_text
        # textarea to email is not in the table, but text to email is
        expect(draft.update_type_de_champ(published.stable_id, type_champ: 'email')).to be_email
        expect(draft.update_type_de_champ(published.stable_id, type_champ: 'text')).to be_text
      end

      it 'refuses any other type, before any copy is made' do
        expect(ClonePiecesJustificativesService).not_to receive(:clone_attachments)

        expect { draft.update_type_de_champ(stable_id('a'), type_champ: 'date') }.to refuse(/« a » ne peut pas devenir « Date »/)
        expect { draft.update_type_de_champ(stable_id('a'), type_champ: 'header_section') }.to refuse
        expect { draft.update_type_de_champ(stable_id('a'), type_champ: 'repetition') }.to refuse
        expect(tdc('a')).to be_text
      end

      it 'keeps the type of a header section and of a repetition' do
        expect { draft.update_type_de_champ(stable_id('s1'), type_champ: 'text') }.to refuse
        expect { draft.update_type_de_champ(stable_id('r'), type_champ: 'text') }.to refuse
        expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }] }, { 'r' => ['r1', 'r2'] }, 'd'])
      end

      it 'leaves a type de champ added since free' do
        added = draft.add_type_de_champ(type_champ: 'text', libelle: 'new')

        expect(draft.update_type_de_champ(added.stable_id, type_champ: 'date')).to be_date
      end
    end
  end

  describe '#accepted_type_champs' do
    it 'accepts what the block allows for a type de champ not published yet' do
      public_type_champs = TypeDeChamp.type_champs.values.reject { TypeDeChamp.find_sti_class(it).private_only? }

      expect(draft.accepted_type_champs(tdc('a'))).to match_array(public_type_champs)
      expect(draft.accepted_type_champs(tdc('r1'))).to match_array(public_type_champs.filter { TypeDeChamp.find_sti_class(it).allowed_in_repetition? })
      expect(draft.accepted_type_champs(tdc('r1'))).not_to include('repetition')
      expect(draft.accepted_type_champs(tdc('p'))).to match_array(TypeDeChamp.type_champs.values.reject { TypeDeChamp.find_sti_class(it).public_only? })
    end

    context 'on a published procedure' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs:, private_type_de_champs:) }

      it 'accepts what the published type converts to' do
        expect(draft.accepted_type_champs(tdc('a'))).to match_array(['text', *Columns::ChampColumn::CAST.keys.filter_map { |from, to| to.to_s if from == :text }])
        expect(draft.accepted_type_champs(tdc('a'))).to include('textarea', 'email')
        expect(draft.accepted_type_champs(tdc('a'))).not_to include('date', 'header_section', 'repetition')
        expect(draft.accepted_type_champs(tdc('s1'))).to eq(['header_section'])
        expect(draft.accepted_type_champs(tdc('r'))).to eq(['repetition'])
      end
    end
  end

  describe '#move_type_de_champ' do
    it 'moves after a sibling, wherever it sits in the block' do
      moved = draft.move_type_de_champ(stable_id('d'), after_stable_id: stable_id('c'))

      expect(moved).to equal(draft.type_de_champ(moved.stable_id))
      expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c', 'd'] }] }, { 'r' => ['r1', 'r2'] }])

      draft.move_type_de_champ(stable_id('r2'), after_stable_id: nil, parent_stable_id: stable_id('r'))

      expect(layout.third).to eq({ 'r' => ['r2', 'r1'] })
    end

    it 'moves first of a header section, or of the form' do
      draft.move_type_de_champ(stable_id('d'), parent_stable_id: stable_id('s1'))
      draft.move_type_de_champ(stable_id('c'))

      expect(layout).to eq(['c', 'a', { 's1' => ['d', 'b', { 's2' => [] }] }, { 'r' => ['r1', 'r2'] }])
    end

    it 'moves a header section and a repetition with what they hold' do
      draft.move_type_de_champ(stable_id('s2'), after_stable_id: stable_id('d'))
      draft.move_type_de_champ(stable_id('r'), parent_stable_id: stable_id('s2'))

      expect(layout).to eq(['a', { 's1' => ['b'] }, 'd', { 's2' => [{ 'r' => ['r1', 'r2'] }, 'c'] }])
    end

    it 'never takes a type de champ out of its block' do
      expect { draft.move_type_de_champ(stable_id('a'), parent_stable_id: stable_id('r')) }.to refuse(/bloc répétable/)
      expect { draft.move_type_de_champ(stable_id('a'), after_stable_id: stable_id('r1')) }.to refuse
      expect { draft.move_type_de_champ(stable_id('r1'), after_stable_id: stable_id('a')) }.to refuse
      expect { draft.move_type_de_champ(stable_id('r1')) }.to refuse
      expect { draft.move_type_de_champ(stable_id('a'), after_stable_id: stable_id('p')) }.to refuse
      expect { draft.move_type_de_champ(stable_id('p'), parent_stable_id: stable_id('s1')) }.to refuse
      expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }] }, { 'r' => ['r1', 'r2'] }, 'd'])
    end

    it 'moves nothing into what holds nothing, nor into itself' do
      expect { draft.move_type_de_champ(stable_id('a'), parent_stable_id: stable_id('d')) }.to refuse(/ne peut rien contenir/)
      expect { draft.move_type_de_champ(stable_id('s2'), parent_stable_id: stable_id('s2')) }.to raise_error(TypeDeChampTree::EditError)
    end

    it 'nests header sections three levels deep at most, in the form as in a repetition' do
      s3 = draft.add_type_de_champ(type_champ: 'header_section', libelle: 's3')
      s4 = draft.add_type_de_champ(type_champ: 'header_section', libelle: 's4', after_stable_id: s3.stable_id)

      draft.move_type_de_champ(s3.stable_id, parent_stable_id: stable_id('s2'))

      expect { draft.move_type_de_champ(s4.stable_id, parent_stable_id: s3.stable_id) }.to refuse('Les titres de section s’imbriquent sur 3 niveaux au plus.')
      # s1 holds two levels: one more above is one too many
      expect { draft.move_type_de_champ(stable_id('s1'), parent_stable_id: s4.stable_id) }.to refuse
      expect { draft.move_type_de_champ(stable_id('s2'), parent_stable_id: s4.stable_id) }.not_to raise_error

      rs = ['rs1', 'rs2', 'rs3', 'rs4'].map { draft.add_type_de_champ(type_champ: 'header_section', libelle: it, parent_stable_id: stable_id('r')) }
      draft.move_type_de_champ(rs.second.stable_id, parent_stable_id: rs.first.stable_id)
      draft.move_type_de_champ(rs.third.stable_id, parent_stable_id: rs.second.stable_id)

      expect { draft.move_type_de_champ(rs.fourth.stable_id, parent_stable_id: rs.third.stable_id) }.to refuse
    end

    it 'cannot move a type de champ which is gone, nor after one which is' do
      expect { draft.move_type_de_champ(-1) }.to raise_error(ActiveRecord::RecordNotFound)
      expect { draft.move_type_de_champ(stable_id('a'), after_stable_id: -1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'moving step by step' do
    it 'moves up before the previous sibling, out of a header section when first, and stays when first of its block' do
      draft.move_up_type_de_champ(stable_id('d'))
      expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }] }, 'd', { 'r' => ['r1', 'r2'] }])

      draft.move_up_type_de_champ(stable_id('c'))
      expect(layout.second).to eq({ 's1' => ['b', 'c', { 's2' => [] }] })

      2.times { draft.move_up_type_de_champ(stable_id('c')) }
      expect(layout.take(3)).to eq(['a', 'c', { 's1' => ['b', { 's2' => [] }] }])

      expect { draft.move_up_type_de_champ(stable_id('a')) }.not_to change { draft.reload.type_de_champ_tree }
      expect { draft.move_up_type_de_champ(stable_id('r1')) }.not_to change { draft.reload.type_de_champ_tree }
    end

    it 'moves down after the next sibling, out of a header section when last, and stays when last of its block' do
      draft.move_down_type_de_champ(stable_id('a'))
      expect(layout.take(2)).to eq([{ 's1' => ['b', { 's2' => ['c'] }] }, 'a'])

      draft.move_down_type_de_champ(stable_id('c'))
      expect(layout.first).to eq({ 's1' => ['b', { 's2' => [] }, 'c'] })

      draft.move_down_type_de_champ(stable_id('c'))
      expect(layout.take(3)).to eq([{ 's1' => ['b', { 's2' => [] }] }, 'c', 'a'])

      expect { draft.move_down_type_de_champ(stable_id('d')) }.not_to change { draft.reload.type_de_champ_tree }
      expect { draft.move_down_type_de_champ(stable_id('r2')) }.not_to change { draft.reload.type_de_champ_tree }
    end

    it 'moves into the header section right before, last' do
      draft.move_in_type_de_champ(stable_id('r'))
      expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }, { 'r' => ['r1', 'r2'] }] }, 'd'])

      expect { draft.move_in_type_de_champ(stable_id('a')) }.to refuse(/n’est pas précédé d’un titre de section/)
      expect { draft.move_in_type_de_champ(stable_id('d')) }.not_to raise_error
      expect { draft.move_in_type_de_champ(stable_id('r2')) }.to refuse
    end

    it 'moves out of its header section, right after it' do
      draft.move_out_type_de_champ(stable_id('c'))
      expect(layout.second).to eq({ 's1' => ['b', { 's2' => [] }, 'c'] })

      draft.move_out_type_de_champ(stable_id('b'))
      expect(layout.take(3)).to eq(['a', { 's1' => [{ 's2' => [] }, 'c'] }, 'b'])

      expect { draft.move_out_type_de_champ(stable_id('a')) }.to refuse(/n’est dans aucune section/)
      expect { draft.move_out_type_de_champ(stable_id('r1')) }.to refuse
    end
  end

  describe '#take_following_siblings' do
    it 'has a header section take the siblings after it, up to the next header section' do
      draft.move_type_de_champ(stable_id('s2'), after_stable_id: stable_id('d'))

      draft.take_following_siblings(stable_id('s1'))

      expect(layout).to eq(['a', { 's1' => ['b', { 'r' => ['r1', 'r2'] }, 'd'] }, { 's2' => ['c'] }])
      expect { draft.take_following_siblings(stable_id('a')) }.to refuse
    end
  end

  describe '#remove_type_de_champ' do
    it 'takes a type de champ out of the tree, and leaves it in the database until the next publication' do
      removed = draft.remove_type_de_champ(stable_id('a'))

      expect(removed.libelle).to eq('a')
      expect(layout).to eq([{ 's1' => ['b', { 's2' => ['c'] }] }, { 'r' => ['r1', 'r2'] }, 'd'])
      expect(TypeDeChamp.find(removed.id)).to be_present
    end

    it 'leaves what a header section held in its place' do
      draft.remove_type_de_champ(stable_id('s1'))

      expect(layout).to eq(['a', 'b', { 's2' => ['c'] }, { 'r' => ['r1', 'r2'] }, 'd'])
    end

    it 'removes a repetition with what it held' do
      draft.remove_type_de_champ(stable_id('r'))

      expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }] }, 'd'])
      expect(draft.type_de_champs.map(&:libelle)).not_to include('r1', 'r2')
    end

    it 'refuses a type de champ the routing, a referentiel or the eligibility rules read, within a repetition too' do
      allow_any_instance_of(Procedure).to receive(:used_by_routing_rules?) { |_, type_de_champ| type_de_champ.libelle == 'a' }
      allow_any_instance_of(Procedure).to receive(:used_by_referentiel_urls?) { |_, type_de_champ| type_de_champ.libelle == 'r1' }
      draft.update!(ineligibilite_enabled: true, ineligibilite_message: 'non', ineligibilite_rules: ds_eq(champ_value(stable_id('d')), constant('x')))

      expect { draft.remove_type_de_champ(stable_id('a')) }.to refuse('« a » est utilisé pour le routage, vous ne pouvez pas le supprimer.')
      expect { draft.remove_type_de_champ(stable_id('r')) }.to refuse('« r1 » est utilisé par un référentiel, vous ne pouvez pas le supprimer.')
      expect { draft.remove_type_de_champ(stable_id('d')) }.to refuse(/inéligibilité/)
      expect(layout).to eq(['a', { 's1' => ['b', { 's2' => ['c'] }] }, { 'r' => ['r1', 'r2'] }, 'd'])
    end

    it 'cannot remove a type de champ which is gone' do
      removed = draft.remove_type_de_champ(stable_id('a'))

      expect { draft.remove_type_de_champ(removed.stable_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'an edit racing with another request' do
    let(:public_type_de_champs) { [{ libelle: 'a' }, { libelle: 'b' }, { libelle: 'c' }] }
    let(:other_request) { ProcedureRevision.find(draft.id) }

    def libelles = draft.reload.public_type_de_champs.map(&:libelle)

    # what the other request commits after this one read the draft and before
    # it got the lock
    def before_the_lock
      done = false
      allow(draft).to receive(:with_lock).and_wrap_original do |with_lock, *args, &edit|
        yield unless done
        done = true
        with_lock.call(*args, &edit)
      end
    end

    it 'adds a type de champ after the one added in the meantime' do
      a = tdc('a')
      before_the_lock { other_request.add_type_de_champ(type_champ: 'text', libelle: 'd', after_stable_id: a.stable_id) }

      draft.add_type_de_champ(type_champ: 'text', libelle: 'e', after_stable_id: a.stable_id)

      expect(libelles).to eq(['a', 'e', 'd', 'b', 'c'])
    end

    it 'adds a type de champ a publication does not purge in the meantime' do
      # holding the lock, a publication purges the types de champ no tree holds
      before_the_lock { procedure.send(:purge_type_de_champs_laid_out_by_no_revision) }

      type_de_champ = draft.add_type_de_champ(type_champ: 'text', libelle: 'd')

      expect(type_de_champ).to eq(draft.type_de_champ(type_de_champ.stable_id))
      expect(libelles).to eq(['d', 'a', 'b', 'c'])
    end

    it 'moves and removes a type de champ from where the others were moved in the meantime' do
      a, b, c = tdc('a'), tdc('b'), tdc('c')
      before_the_lock { other_request.move_type_de_champ(c.stable_id) }

      draft.move_type_de_champ(a.stable_id, after_stable_id: b.stable_id)

      expect(libelles).to eq(['c', 'b', 'a'])

      other_request.move_up_type_de_champ(a.stable_id)
      draft.remove_type_de_champ(c.stable_id)

      expect(libelles).to eq(['a', 'b'])
    end

    it 'moves nothing when the type de champ was removed in the meantime' do
      a, b = tdc('a'), tdc('b')
      before_the_lock { other_request.remove_type_de_champ(a.stable_id) }

      expect { draft.move_down_type_de_champ(a.stable_id) }.to raise_error(ActiveRecord::RecordNotFound)
      expect { draft.move_type_de_champ(b.stable_id, after_stable_id: a.stable_id) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(libelles).to eq(['b', 'c'])
    end

    context 'on a published procedure' do
      let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ libelle: 'a' }]) }

      it 'edits the copy made in the meantime rather than making another' do
        published_type_de_champ = procedure.published_revision.public_type_de_champs.first
        stable_id = published_type_de_champ.stable_id
        before_the_lock { other_request.update_type_de_champ(stable_id, libelle: 'a bis') }

        type_de_champ = draft.find_and_ensure_exclusive_use(stable_id)

        expect(type_de_champ.libelle).to eq('a bis')
        expect(TypeDeChamp.where(stable_id:)).to contain_exactly(published_type_de_champ, type_de_champ)
      end

      it 'edits nothing of the revision published in the meantime' do
        stable_id = draft.public_type_de_champs.first.stable_id
        before_the_lock { Procedure.find(procedure.id).publish_revision!(procedure.administrateurs.first) }

        expect { draft.add_type_de_champ(type_champ: 'text', libelle: 'd') }.to raise_error(ActiveRecord::RecordNotFound)
        expect { draft.remove_type_de_champ(stable_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { draft.move_up_type_de_champ(stable_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { draft.find_and_ensure_exclusive_use(stable_id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect { draft.update_type_de_champ(stable_id, libelle: 'a bis') }.to raise_error(ActiveRecord::RecordNotFound)

        expect(procedure.reload.published_revision).to eq(draft)
        expect(procedure.published_revision.type_de_champs.map(&:libelle)).to eq(['a'])
        expect(procedure.type_de_champs.where(libelle: 'd')).to be_empty
        expect(TypeDeChamp.where(stable_id:).count).to eq(1)
      end
    end
  end

  describe '#apply_llm_rule_suggestion_items' do
    let(:public_type_de_champs) { [{ libelle: 'a', stable_id: 1 }, { libelle: 'b', stable_id: 2 }, { libelle: 'c', stable_id: 3 }, { type: :header_section, libelle: 's', stable_id: 4, children: [{ libelle: 'd', stable_id: 5 }] }] }
    let(:schema_hash) { Digest::SHA256.hexdigest(draft.schema_to_llm.to_json) }
    let(:llm_rule_suggestion) { create(:llm_rule_suggestion, procedure_revision: draft, rule:, schema_hash:) }
    let(:rule) { LLMRuleSuggestion.rules.fetch('improve_structure') }

    def item(op_kind, payload, stable_id: payload['stable_id'])
      create(:llm_rule_suggestion_item, llm_rule_suggestion:, verify_status: 'accepted', stable_id:, op_kind:, payload:)
    end

    def apply = draft.apply_llm_rule_suggestion_items(llm_rule_suggestion.changes_to_apply)

    it 'adds header sections, each taking what follows it up to the next one' do
      item('add', { 'generated_stable_id' => -1, 'after_stable_id' => nil, 'libelle' => 's0' })
      item('add', { 'generated_stable_id' => -2, 'after_stable_id' => 2, 'libelle' => 's1' })
      item('add', { 'generated_stable_id' => -3, 'parent_stable_id' => -2, 'after_stable_id' => nil, 'libelle' => 's2' })

      apply

      expect(layout).to eq([{ 's0' => ['a', 'b'] }, { 's1' => [{ 's2' => ['c'] }] }, { 's' => ['d'] }])
    end

    it 'applies every suggestion under one lock, the tree written once' do
      item('add', { 'generated_stable_id' => -1, 'after_stable_id' => 1, 'libelle' => 's0' })
      item('update', { 'stable_id' => 2, 'libelle' => 'b bis' })
      item('update', { 'stable_id' => 3, 'type_champ' => 'formatted', 'options' => { 'formatted_mode' => 'simple' } })
      item('destroy', {}, stable_id: 5)
      expect(draft).to receive(:with_lock).once.and_call_original
      expect(draft).to receive(:write_type_de_champ_tree).once.and_call_original

      apply

      expect(layout).to eq(['a', { 's0' => ['b bis', 'c'] }, { 's' => [] }])
      expect(tdc('c')).to be_formatted
      expect(llm_rule_suggestion.llm_rule_suggestion_items.reload).to all(be_accepted)
    end

    it 'marks as failed the suggestions the rules refuse or whose type de champ is gone, and applies the others' do
      gone = item('update', { 'stable_id' => -12, 'libelle' => 'gone' })
      refused = item('update', { 'stable_id' => 5, 'type_champ' => 'header_section' }).tap do
        # d sits three header sections deep by then
        ['s1', 's2'].reduce(4) { |parent_stable_id, libelle| draft.add_type_de_champ(type_champ: 'header_section', libelle:, parent_stable_id:).stable_id }
        draft.move_type_de_champ(5, parent_stable_id: stable_id('s2'))
      end
      applied = item('update', { 'stable_id' => 1, 'libelle' => 'a bis' })

      apply

      expect([gone, refused].map(&:reload)).to all(be_failed)
      expect(applied.reload).to be_accepted
      expect(tdc('a bis')).to be_present
      expect(tdc('d')).to be_text
    end
  end
end
