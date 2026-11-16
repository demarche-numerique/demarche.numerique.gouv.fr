# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TypeDeChamps::LibelleValidator do
  let(:procedure) { create(:procedure, public_type_de_champs: types) }
  let(:type_de_champ) { procedure.active_revision.public_root_type_de_champs.first }

  subject { procedure.validate(:public_type_de_champs_editor) }

  context 'with a text type de champ' do
    let(:types) { [type: :text] }

    context 'when libelle is filled' do
      it 'does not add errors to the procedure' do
        expect { subject }.not_to change { procedure.errors.count }
      end
    end

    context 'when libelle is empty' do
      before { type_de_champ.update(libelle: '') }

      it 'does add errors to the procedure' do
        expect { subject }.to change { procedure.errors.count }
      end
    end

    context 'when libelle is nil' do
      before { type_de_champ.update(libelle: nil) }

      it 'does add errors to the procedure' do
        expect { subject }.to change { procedure.errors.count }
      end
    end
  end

  context 'with a champ inside a repetition' do
    let(:types) { [{ type: :repetition, children: [{ type: :text }] }] }
    let(:repetition) { procedure.active_revision.public_root_type_de_champs.find(&:repetition?) }
    let(:child) { procedure.draft_revision.type_de_champ(repetition.stable_id).flat_children.first }

    context 'when the child libelle is empty' do
      before { child.update(libelle: '') }

      it 'adds an error mentioning both the child position and the parent repetition position' do
        subject

        expect(procedure.errors.messages_for(:public_draft_type_de_champs))
          .to include(
            I18n.t(
              'activerecord.errors.models.procedure.attributes.public_draft_type_de_champs.missing_libelle_in_repetition',
              position: child.revision_type_de_champs.last.position + 1,
              parent_position: repetition.revision_type_de_champs.last.position + 1
            )
          )
      end
    end
  end

  context 'when the type de champ without libelle was removed by another request in the meantime' do
    let(:types) { [{ type: :text, libelle: 'a' }, { type: :text, libelle: 'b' }] }

    before do
      removed = procedure.draft_revision.public_root_type_de_champs.second
      removed.update(libelle: '')
      ProcedureRevision.find(procedure.draft_revision_id).remove_type_de_champ(removed.stable_id)
    end

    it 'reports the position the loaded draft lays it at (RAILS-MMV)' do
      subject

      expect(procedure.errors.messages_for(:public_draft_type_de_champs))
        .to include(I18n.t('activerecord.errors.models.procedure.attributes.public_draft_type_de_champs.missing_libelle', position: 2))
    end
  end

  context 'with a champ in a header section' do
    let(:types) { [{ type: :text, libelle: 'a' }, { type: :header_section, level: 1, libelle: 'h' }, { type: :text, libelle: 'b' }] }

    before { procedure.draft_revision.public_root_type_de_champs.third.update(libelle: '') }

    it 'reports the number the editor shows' do
      subject

      expect(procedure.errors.messages_for(:public_draft_type_de_champs))
        .to include(I18n.t('activerecord.errors.models.procedure.attributes.public_draft_type_de_champs.missing_libelle', position: 3))
    end
  end

  context 'with linked drop down list type de champ' do
    let(:types) { [type: :linked_drop_down_list] }
    context 'when libelle is filled' do
      it 'does not add errors to the procedure' do
        expect { subject }.not_to change { procedure.errors.count }
      end
    end

    context 'when libelle is empty' do
      before { type_de_champ.update(libelle: '') }

      it 'does add errors to the procedure' do
        expect { subject }.to change { procedure.errors.count }
      end
    end

    context 'when libelle is nil' do
      before { type_de_champ.update(libelle: nil) }

      it 'does add errors to the procedure' do
        expect { subject }.to change { procedure.errors.count }
      end
    end
  end

  context 'with an explication type de champ' do
    let(:types) { [type: :explication] }

    before { type_de_champ.update(libelle: '') }

    it 'does not add errors to the procedure' do
      expect { subject }.not_to change { procedure.errors.count }
    end
  end
end
