# frozen_string_literal: true

RSpec.describe PrefillTypeDeChampsController, type: :controller do
  describe '#show' do
    let(:type_de_champ) { create(:type_de_champ_text, procedure: procedure) }
    subject(:show_request) { get :show, params: { path: procedure.path, id: type_de_champ.id } }

    context 'when the procedure is found' do
      context 'when the procedure is publiee' do
        context 'when the procedure is opendata' do
          render_views

          let(:procedure) { create(:procedure, :published, opendata: true) }

          it { expect(show_request).to render_template(:show) }

          context 'when the type de champ is not found' do
            let(:type_de_champ) { double(TypeDeChamp, id: -1) }

            it { expect { show_request }.to raise_error(ActiveRecord::RecordNotFound) }
          end
        end

        context 'when the procedure is not opendata' do
          let(:procedure) { create(:procedure, :published, opendata: false) }

          it { expect { show_request }.to raise_error(ActiveRecord::RecordNotFound) }
        end
      end

      context 'when the procedure is brouillon' do
        context 'when the procedure is opendata' do
          let(:procedure) { create(:procedure, :draft, opendata: true) }

          it { expect(show_request).to render_template(:show) }

          context 'when the type de champ is not found' do
            let(:type_de_champ) { double(TypeDeChamp, id: -1) }

            it { expect { show_request }.to raise_error(ActiveRecord::RecordNotFound) }
          end
        end

        context 'when the procedure is not opendata' do
          let(:procedure) { create(:procedure, :draft, opendata: false) }

          it { expect { show_request }.to raise_error(ActiveRecord::RecordNotFound) }
        end
      end

      context 'when the procedure is not publiee and not brouillon' do
        let(:procedure) { create(:procedure, :closed) }

        it { expect { show_request }.to raise_error(ActiveRecord::RecordNotFound) }
      end

      context 'when the requested type de champ is a private annotation' do
        let(:procedure) { create(:procedure, :published, opendata: true) }
        let(:type_de_champ) { create(:type_de_champ_text, :private, procedure: procedure) }

        subject(:show_request) { get :show, params: { path: procedure.path, id: type_de_champ.stable_id } }

        it 'does not expose the private annotation' do
          expect { show_request }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'when the procedure is not found' do
      let(:procedure) { create(:procedure, :published, opendata: true) }
      subject(:show_request) { get :show, params: { path: "wrong path", id: type_de_champ.id } }

      it { expect { show_request }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end
end
