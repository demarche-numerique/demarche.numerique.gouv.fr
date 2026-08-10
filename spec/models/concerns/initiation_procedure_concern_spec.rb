# frozen_string_literal: true

describe InitiationProcedureConcern do
  describe '.create_initiation_procedure' do
    let(:administrateur) { administrateurs.default }
    subject { Procedure.create_initiation_procedure(administrateur) }

    it "returns a new procedure" do
      subject
      subject.reload
      expect(subject).to be_valid
      expect(subject.defaut_groupe_instructeur.instructeurs.count).to eq(1)
      expect(subject.draft_revision.root_public_types_de_champ).not_to be_empty
      expect(subject.service).not_to be_nil
    end
  end
end
