# frozen_string_literal: true

describe PasswordComplexityController, type: :controller do
  describe '#show' do
    let(:params) do
      { user: { password: 'motDePasseTropFacile' } }
    end

    subject { post :show, format: :turbo_stream, params: params }

    it 'computes a password score' do
      subject
      expect(assigns(:score)).to eq(3)
    end

    context 'with a different resource name' do
      let(:params) do
        { super_admin: { password: 'motDePasseTropFacile' } }
      end

      it 'computes a password score' do
        subject
        expect(assigns(:score)).to eq(3)
      end
    end

    context 'when rendering the view' do
      render_views

      it 'renders Javascript that updates the password complexity meter' do
        subject
        expect(response.body).to include('Mot de passe vulnérable')
      end
    end

    context 'when the password exceeds the maximum length' do
      let(:long_password) { 'a' * 5_000 }
      let(:params) { { user: { password: long_password } } }

      it 'truncates the password to Devise max length before scoring to prevent DoS' do
        max = Devise.password_length.max
        expect(ZxcvbnService).to receive(:complexity).with(satisfy { |arg| arg.length <= max }).and_return(0)
        subject
      end
    end
  end
end
