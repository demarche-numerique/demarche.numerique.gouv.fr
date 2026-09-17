# frozen_string_literal: true

describe 'invites locales accessibility' do
  describe 'success messages' do
    let(:email) { 'test@example.fr' }

    describe 'create success message' do
      let(:message_fr) { I18n.t('views.invites.create.success', email: email, locale: :fr) }
      let(:message_en) { I18n.t('views.invites.create.success', email: email, locale: :en) }

      it 'uses a button element (not a link) in French locale for reopening modal' do
        expect(message_fr).to include('<button')
        expect(message_fr).not_to include('<a ')
        expect(message_fr).not_to include('href="#"')
      end

      it 'uses a button element (not a link) in English locale for reopening modal' do
        expect(message_en).to include('<button')
        expect(message_en).not_to include('<a ')
        expect(message_en).not_to include('href="#"')
      end
    end

    describe 'destroy success message' do
      let(:message_fr) { I18n.t('views.invites.destroy.success', email: email, locale: :fr) }
      let(:message_en) { I18n.t('views.invites.destroy.success', email: email, locale: :en) }

      it 'uses a button element (not a link) in French locale for reopening modal' do
        expect(message_fr).to include('<button')
        expect(message_fr).not_to include('<a ')
        expect(message_fr).not_to include('href="#"')
      end

      it 'uses a button element (not a link) in English locale for reopening modal' do
        expect(message_en).to include('<button')
        expect(message_en).not_to include('<a ')
        expect(message_en).not_to include('href="#"')
      end
    end
  end
end
