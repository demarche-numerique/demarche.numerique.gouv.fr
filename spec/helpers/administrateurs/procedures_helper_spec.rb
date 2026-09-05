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

  describe '#visible_filter_tags_count' do
    let(:admin) { create(:administrateur) }
    context 'on the all action' do
      before { allow(helper).to receive(:action_name).and_return('all') }

      it 'counts each active filter as one tag' do
        filter = ProceduresFilter.new(admin, ActionController::Parameters.new(statuses: ['publiee', 'close']))
        expect(helper.visible_filter_tags_count(filter)).to eq(2)
      end

      it 'counts procedure-only filters like template' do
        filter = ProceduresFilter.new(admin, ActionController::Parameters.new(template: '1'))
        expect(helper.visible_filter_tags_count(filter)).to eq(1)
      end

      it 'returns 0 when no filter is active' do
        filter = ProceduresFilter.new(admin, ActionController::Parameters.new({}))
        expect(helper.visible_filter_tags_count(filter)).to eq(0)
      end
    end

    context 'on the administrateurs action' do
      before { allow(helper).to receive(:action_name).and_return('administrateurs') }

      it 'excludes procedure-only filters like template' do
        filter = ProceduresFilter.new(admin, ActionController::Parameters.new(template: '1'))
        expect(helper.visible_filter_tags_count(filter)).to eq(0)
      end

      it 'still counts shared filters like email' do
        filter = ProceduresFilter.new(admin, ActionController::Parameters.new(email: 'test@exemple.fr'))
        expect(helper.visible_filter_tags_count(filter)).to eq(1)
      end
    end
  end
end
