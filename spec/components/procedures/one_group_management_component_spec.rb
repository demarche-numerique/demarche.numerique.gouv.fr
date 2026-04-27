# frozen_string_literal: true

describe Procedure::OneGroupeManagementComponent, type: :component do
  include Logic

  describe 'render' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [{ type: :integer_number, libelle: 'Age' }])
        .tap { _1.groupe_instructeurs.create(label: 'groupe 2') }
    end

    subject do
      render_inline(described_class.new(revision: procedure.active_revision,
        groupe_instructeur: procedure.defaut_groupe_instructeur))
    end

    context 'when there are types de champ that can be routed' do
      before do
        procedure.draft_revision.add_type_de_champ({
          type_champ: :drop_down_list,
          libelle: 'Votre ville',
          drop_down_options: ["Paris", "Lyon", "Marseille"],
        })
        procedure.publish_revision!(procedure.administrateurs.first)
        procedure.reload
        allow_any_instance_of(Conditions::RoutingRulesComponent)
          .to receive(:feature_enabled?).with(:column_conditions).and_return(false)
        subject
      end
      it { expect(page).to have_text('aucune règle') }
    end
  end
end
