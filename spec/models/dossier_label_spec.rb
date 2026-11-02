# frozen_string_literal: true

describe DossierLabel do
  let(:procedure) { create(:procedure, :with_labels) }
  let(:dossier) { create(:dossier, procedure:) }

  describe 'label_belongs_to_dossier_procedure' do
    context 'when the label belongs to the dossier procedure' do
      let(:label) { procedure.labels.first }

      it 'is valid' do
        expect(DossierLabel.new(dossier:, label:)).to be_valid
      end
    end

    context 'when the label belongs to another procedure' do
      let(:label) { create(:procedure, :with_labels).labels.first }

      it 'is invalid' do
        expect(DossierLabel.new(dossier:, label:)).not_to be_valid
      end
    end
  end

  describe 'touching the dossier' do
    let(:label) { procedure.labels.first }

    it 'bumps dossier.updated_at when a label is added' do
      dossier.update_column(:updated_at, 1.day.ago)

      expect { DossierLabel.create!(dossier:, label:) }
        .to(change { dossier.reload.updated_at })
    end

    it 'bumps dossier.updated_at when a label is removed' do
      dossier_label = DossierLabel.create!(dossier:, label:)
      dossier.update_column(:updated_at, 1.day.ago)

      expect { dossier_label.destroy }
        .to(change { dossier.reload.updated_at })
    end
  end

  describe 'Dossier#add_label and #remove_label' do
    let(:label) { procedure.labels.first }

    it 'adds a label once' do
      expect { 2.times { dossier.add_label(label) } }
        .to change { dossier.labels.count }.by(1)
      expect(dossier.add_label(label)).not_to be_previously_new_record
    end

    it 'removes a label, returning nil when it is not on the dossier' do
      dossier.add_label(label)

      expect { expect(dossier.remove_label(label)).to be_destroyed }
        .to change { dossier.labels.count }.by(-1)
      expect(dossier.remove_label(label)).to be_nil
    end
  end
end
