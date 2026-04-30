# frozen_string_literal: true

describe Administrateurs::ProceduresHelper, type: :helper do
  describe '#render_procedure_sticky_title' do
    let(:procedure) { create(:procedure, libelle: 'Démarche test') }

    before { helper.render_procedure_sticky_title(procedure) }

    subject { helper.content_for(:sticky_header) }

    it 'injects sticky title markup into :sticky_header content_for' do
      expect(subject).to include('procedure-sticky-title')
      expect(subject).to match(/aria-hidden=["']true["']/)
      expect(subject).to include('Démarche test')
      expect(subject).to include(procedure.id.to_s)
    end
  end
end
