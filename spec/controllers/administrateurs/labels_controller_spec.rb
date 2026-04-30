# frozen_string_literal: true

describe Administrateurs::LabelsController, type: :controller do
  let(:admin) { administrateurs(:default_admin) }
  let(:procedure) { create(:procedure, administrateur: admin) }
  let(:admin_2) { create(:administrateur) }
  let(:procedure_2) { create(:procedure, administrateur: admin_2) }

  describe '#index' do
    render_views
    let!(:label_1) { create(:label, procedure:) }
    let!(:label_2) { create(:label, procedure:) }
    let!(:label_3) { create(:label, procedure:) }

    before do
      sign_in(admin.user)
    end

    subject { get :index, params: { procedure_id: procedure.id } }

    it 'displays all procedure labels' do
      subject
      expect(response.body).to have_link("Nouveau label")
      expect(response.body).to have_link("Modifier", count: 3)
      expect(response.body).to have_link("Supprimer", count: 3)
    end
  end

  describe '#create' do
    before do
      sign_in(admin.user)
    end

    subject { post :create, params: params }

    context 'when submitting a new label' do
      let(:params) do
        {
          label: {
            name: 'Nouveau label',
                    color: 'green-bourgeon',
          },
        procedure_id: procedure.id,
        }
      end

      it { expect { subject }.to change { Label.count } .by(1) }

      it 'creates a new label' do
        subject
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq('Le label a bien été créé')
        expect(Label.last.name).to eq('Nouveau label')
        expect(Label.last.color).to eq('green_bourgeon')
        expect(procedure.labels.last).to eq(Label.last)
      end
    end

    context 'when submitting an invalid label' do
      let(:params) { { label: { name: 'Nouveau label' }, procedure_id: procedure.id } }

      it { expect { subject }.not_to change { Label.count } }

      it 'does not create a new label' do
        subject
        expect(flash.alert).to eq(["Le champ « Couleur » doit être rempli"])
        expect(response).to render_template(:new)
        expect(assigns(:label).name).to eq('Nouveau label')
      end
    end

    context 'when submitting a label for a not own procedure' do
      let(:params) do
        {
          label: {
            name: 'Nouveau label',
            color: 'green-bourgeon',
          },
        procedure_id: procedure_2.id,
        }
      end

      it { expect { subject }.not_to change { Label.count } }

      it 'does not create a new label' do
        subject
        expect(flash.alert).to eq("Démarche inexistante")
        expect(response.status).to eq(404)
      end
    end
  end

  describe '#update' do
    let!(:label) { create(:label, procedure:) }
    let(:label_params) { { name: 'Nouveau nom' } }
    let(:params) { { id: label.id, label: label_params, procedure_id: procedure.id } }

    before do
      sign_in(admin.user)
    end

    subject { patch :update, params: }

    context 'when updating a label' do
      it 'updates correctly' do
        travel(1.second)
        subject
        expect(flash.alert).to be_nil
        expect(flash.notice).to eq('Le label a bien été modifié')
        expect(label.reload.name).to eq('Nouveau nom')
        expect(label.reload.color).to eq('green_bourgeon')
        expect(label.reload.updated_at).not_to eq(label.reload.created_at)
        expect(response).to redirect_to(admin_procedure_labels_path(procedure_id: procedure.id))
      end
    end

    context 'when updating a service with invalid data' do
      let(:label_params) { { name: '' } }

      it 'does not update' do
        subject
        expect(flash.alert).not_to be_nil
        expect(response).to render_template(:edit)
        expect(label.reload.updated_at).to eq(label.reload.created_at)
      end
    end

    context 'when updating a label for a not own procedure' do
      let(:params) { { id: label.id, label: label_params, procedure_id: procedure_2.id } }

      it 'does not update' do
        subject
        expect(label.reload.updated_at).to eq(label.reload.created_at)
      end
    end
  end

  describe '#update_order_positions' do
    before do
      sign_in(admin.user)
    end

    subject { patch :update_order_positions, params: }

    context 'when reordering labels of own procedure' do
      let!(:label_a) { create(:label, procedure:, position: 0) }
      let!(:label_b) { create(:label, procedure:, position: 1) }
      let(:params) { { procedure_id: procedure.id, ordered_label_ids: [label_b.id, label_a.id] } }

      it 'updates positions of procedure labels' do
        subject
        expect(label_a.reload.position).to eq(1)
        expect(label_b.reload.position).to eq(0)
      end
    end

    context 'when ordered_label_ids reference labels of another procedure' do
      let!(:other_label_first)  { create(:label, procedure: procedure_2, position: 0) }
      let!(:other_label_second) { create(:label, procedure: procedure_2, position: 1) }
      let!(:other_label_third)  { create(:label, procedure: procedure_2, position: 2) }

      let(:params) do
        {
          procedure_id: procedure.id,
          ordered_label_ids: [other_label_third.id, other_label_second.id, other_label_first.id],
        }
      end

      it 'does not change positions of labels belonging to another procedure' do
        expect { subject }.not_to change { Label.where(procedure: procedure_2).order(:id).pluck(:position) }
      end
    end
  end

  describe '#destroy' do
    let(:label) { create(:label, procedure:) }

    before do
      sign_in(admin.user)
    end

    subject { delete :destroy, params: }

    context "when deleting a label" do
      let(:params) { { id: label.id, procedure_id: procedure.id } }

      it "delete the label" do
        subject
        expect { label.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(flash.notice).to eq('Le label a bien été supprimé')
        expect(response).to redirect_to(admin_procedure_labels_path(procedure_id: procedure.id))
      end
    end

    context 'when deleting a label for a not own procedure' do
      let(:params) { { id: label.id, procedure_id: procedure_2.id } }

      it 'does not delete' do
        subject
        expect(flash.alert).to eq("Démarche inexistante")
        expect(response.status).to eq(404)
        expect { label.reload }.not_to raise_error
      end
    end
  end
end
