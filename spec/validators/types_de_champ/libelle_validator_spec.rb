# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TypesDeChamp::LibelleValidator do
  let(:procedure) { create(:procedure, types_de_champ_public: types) }
  let(:type_de_champ) { procedure.active_revision.root_public_types_de_champ.first }

  subject { procedure.validate(:types_de_champ_public_editor) }

  context 'with a text type de champ' do
    let(:types) { [type: :text] }

    context 'when libelle is filled' do
      it 'does not add errors to the procedure' do
        expect { subject }.not_to change { procedure.errors.count }
      end
    end

    context 'when libelle is empty' do
      before { type_de_champ.record.update(libelle: '') }

      it 'does add errors to the procedure' do
        expect { subject }.to change { procedure.errors.count }
      end
    end

    context 'when libelle is nil' do
      before { type_de_champ.record.update(libelle: nil) }

      it 'does add errors to the procedure' do
        expect { subject }.to change { procedure.errors.count }
      end
    end
  end

  context 'with a champ inside a repetition' do
    let(:types) { [{ type: :repetition, children: [{ type: :text }] }] }
    let(:repetition) { procedure.active_revision.root_public_types_de_champ.find(&:repetition?) }
    let(:child) { repetition.flat_children.first }

    context 'when the child libelle is empty' do
      before { child.record.update(libelle: '') }

      it 'adds an error mentioning both the child position and the parent repetition position' do
        subject

        expect(procedure.errors.messages_for(:draft_types_de_champ_public))
          .to include(
            I18n.t(
              'activerecord.errors.models.procedure.attributes.draft_types_de_champ_public.missing_libelle_in_repetition',
              position: child.revision_types_de_champ.last.position + 1,
              parent_position: repetition.revision_types_de_champ.last.position + 1
            )
          )
      end
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
      before { type_de_champ.record.update(libelle: '') }

      it 'does add errors to the procedure' do
        expect { subject }.to change { procedure.errors.count }
      end
    end

    context 'when libelle is nil' do
      before { type_de_champ.record.update(libelle: nil) }

      it 'does add errors to the procedure' do
        expect { subject }.to change { procedure.errors.count }
      end
    end
  end
end
