# frozen_string_literal: true

describe ProcedurePathConcern do
  describe "#destroy" do
    let!(:procedure) { create(:procedure) }

    context "when there is only one procedure_path (the uuid)" do
      it do
        procedure_path = procedure.procedure_paths.first
        expect { procedure_path.destroy }.not_to change { procedure.procedure_paths.count }
        expect { procedure_path.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      end
    end

    context "when there is more than one procedure_path" do
      let!(:procedure_path1) { procedure.procedure_paths.create(path: "path1") }

      it { expect { procedure_path1.destroy }.to change { procedure.procedure_paths.count }.from(2).to(1) }
    end
  end

  describe ".find_with_path" do
    let!(:procedure1) { create(:procedure) }

    let!(:procedure_path1) { procedure1.procedure_paths.create(path: "test-path-1") }

    context "when a procedure with the given path exists" do
      it "returns the procedure with the matching path" do
        result = Procedure.find_with_path("test-path-1").first

        expect(result).to eq(procedure1)
      end

      context "when the path is in uppercase or has trailing spaces" do
        it "returns the procedure with the matching path" do
          result = Procedure.find_with_path("TEST-PATH-1 ").first

          expect(result).to eq(procedure1)
        end
      end
    end

    context "when no procedure with the given path exists" do
      it "returns an empty result" do
        result = Procedure.find_with_path("unknown-path").first

        expect(result).to be_nil
      end
    end
  end

  describe 'path_customized?' do
    let!(:procedure) { create :procedure }

    subject { procedure.path_customized? }

    context 'when the path is still the default' do
      it { is_expected.to be_falsey }
    end

    context 'when the path has been changed' do
      before do
        travel(1.minute)
        procedure.claim_path!(procedure.administrateurs.first, 'custom_path')
      end

      it do
        expect(procedure.path).to eq('custom_path')
        is_expected.to be_truthy
      end
    end
  end

  describe '#canonical_path' do
    let!(:procedure) do
      travel_to(3.days.ago) do
        create(:procedure)
      end
    end

    before do
      travel_to(2.days.ago) do
        create(:procedure_path,
          procedure: procedure,
          path: 'older-path')
      end

      travel_to(1.day.ago) do
        create(:procedure_path,
          procedure: procedure,
          path: 'newer-path')
      end

      travel_to(10.days.ago) do
        create(:procedure_path,
          procedure: procedure,
          path: 'other-path')
      end
    end

    it 'returns the path of the most recently updated procedure_path' do
      expect(procedure.canonical_path).to eq('newer-path')
    end
  end

  describe "#claim_path!" do
    let!(:procedure) { create(:procedure) }
    let!(:procedure_path) { create(:procedure_path, procedure: procedure, path: "test-path") }
    let!(:procedure_2) { create(:procedure) }
    let!(:procedure_path_2) { create(:procedure_path, procedure: procedure_2, path: "test-path-2") }
    let(:administrateur) { procedure.administrateurs.first }

    let(:path_to_claim) { procedure_path_2.path }

    subject do
      procedure.claim_path!(administrateur, path_to_claim)
      procedure.save!
    end

    it "assigns the procedure to the procedure_path" do
      expect { subject }.to change { procedure_path_2.reload.procedure }.from(procedure_2).to(procedure)
    end

    context "when the procedure path is already owned by another administrateur" do
      let!(:procedure_3) { create(:procedure, administrateurs: [create(:administrateur)]) }
      let!(:procedure_path_3) { create(:procedure_path, procedure: procedure_3, path: "path-not-available") }

      let(:path_to_claim) { procedure_path_3.path }

      it "does not assign the procedure to the procedure_path" do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
        expect(procedure.errors.full_messages).to include("Le champ « Lien public » est déjà utilisé par une démarche. Vous ne pouvez pas l’utiliser car il appartient à un autre administrateur.")
      end
    end

    context "when trying to claim the last procedure_path of another procedure" do
      let!(:procedure_2) { create(:procedure) }

      before do
        first_procedure_path = procedure_2.procedure_paths.order(:created_at).first
        procedure_2.procedure_paths.where.not(id: first_procedure_path.id).delete_all
      end

      let(:path_to_claim) { procedure_2.canonical_path }

      it "does not assign the procedure to the procedure_path" do
        expect(procedure_2.procedure_paths.count).to eq(1)
        expect(procedure_2.canonical_path).to eq(procedure_2.procedure_paths.first.path)
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
        expect(procedure.errors.full_messages).to include("Le champ « Lien public » ne peut pas être utilisé car c’est le dernier lien de la démarche.")
      end
    end
  end

  describe '#previous_paths' do
    let!(:procedure) { create(:procedure) }

    context 'when the path has been changed twice' do
      before do
        travel(1.minute)
        procedure.claim_path!(procedure.administrateurs.first, 'custom_path')
        procedure.save!
        procedure.reload

        travel(2.minutes)
        procedure.claim_path!(procedure.administrateurs.first, 'custom_path_2')
      end

      it "should only contain the paths that are not the current one nor the uuid" do
        expect(procedure.previous_paths.map(&:path)).to eq(['custom_path'])
      end
    end
  end
end
