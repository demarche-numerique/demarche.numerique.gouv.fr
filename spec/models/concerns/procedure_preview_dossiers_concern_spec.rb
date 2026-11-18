# frozen_string_literal: true

describe ProcedurePreviewDossiersConcern do
  let(:procedure) { procedures.individual }
  let(:seeded) { procedure.dossiers.index_by(&:state) }

  describe '#preview_dossiers' do
    let(:states) { -> (**options) { procedure.preview_dossiers(states: ['en_construction', 'en_instruction', 'accepte'], **options).transform_values { it.map(&:state) } } }

    it 'offers the given states, the last one first' do
      expect(states.()).to eq(current: ['accepte', 'en_instruction', 'en_construction'])
    end

    it 'keeps every state within the limit' do
      create_list(:dossier, 2, :accepte, procedure:, depose_at: Time.current)

      expect(states.(limit: 3)).to eq(current: ['accepte', 'en_instruction', 'en_construction'])
    end

    it 'splits off the dossiers of previous revisions, last state first, then the most recent deposits' do
      seeded.fetch('en_construction').update_columns(depose_at: 1.hour.ago)
      seeded.fetch('en_instruction').update_columns(depose_at: 2.hours.ago)
      seeded.fetch('accepte').update_columns(depose_at: 3.hours.ago, revision_id: procedure.draft_revision.id)

      expect(states.()).to eq(current: ['en_construction', 'en_instruction'], previous: ['accepte'])
    end
  end

  describe '#preview_dossier' do
    it 'finds a dossier of the procedure visible by the administration' do
      expect(procedure.preview_dossier(seeded.fetch('accepte').id)).to eq(seeded.fetch('accepte'))
    end

    it 'ignores a brouillon, a dossier of another procedure or a blank id' do
      expect(procedure.preview_dossier(seeded.fetch('brouillon').id)).to be_nil
      expect(procedure.preview_dossier(create(:dossier, :accepte).id)).to be_nil
      expect(procedure.preview_dossier(nil)).to be_nil
    end
  end
end
