# frozen_string_literal: true

describe 'experts/avis/index', type: :view do
  let(:expert) { experts.default }
  let(:procedure) { procedures.individual }
  let(:pending_avis) { avis.pending }

  before do
    allow(view).to receive(:current_expert).and_return(expert)
    assign(:avis_by_procedure, [pending_avis].group_by(&:procedure))
  end

  subject { render }

  it 'renders avis in a list view' do
    expect(subject).to have_text(pending_avis.procedure.libelle)
    expect(subject).to have_text("avis à donner")
  end

  context 'dossier is termine' do
    before do
      pending_avis.dossier.update!(state: "accepte")
    end

    it 'doesn’t count avis a donner when dossier is termine' do
      expect(subject).to have_selector("##{dom_id(procedure)}", text: 0)
    end
  end

  context 'when the dossier is deleted by instructeur' do
    before do
      pending_avis.dossier.update!(state: "accepte", hidden_by_administration_at: Time.zone.now.beginning_of_day.utc)
      avis.answered.dossier.update!(hidden_by_administration_at: Time.zone.now.beginning_of_day.utc)
      assign(:avis_by_procedure, expert.avis.includes(dossier: [groupe_instructeur: :procedure]).where(dossiers: { hidden_by_administration_at: nil }).to_a.group_by(&:procedure))
    end

    it 'doesn’t display the avis' do
      expect(subject).not_to have_text(pending_avis.procedure.libelle)
      expect(subject).not_to have_text("avis à donner")
    end
  end
end
