# frozen_string_literal: true

describe TabsHelper, type: :helper do
  describe '#tab_item' do
    subject { Capybara.string(helper.tab_item(label, '/avis', notification:, notification_key:)) }

    let(:label) { 'Avis externes' }
    let(:notification) { true }
    let(:notification_key) { :avis_externe }

    it 'identifies the sticker by its key, not by the label' do
      expect(subject).to have_css("span.notifications##{helper.notification_sticker_id(:avis_externe)}")
    end

    context 'when the label is translated' do
      let(:label) { 'External opinion' }

      it { is_expected.to have_css('span.notifications#notification-sticker-avis_externe') }
    end

    context 'without a notification key' do
      let(:notification_key) { nil }

      it 'renders a sticker without id' do
        expect(subject).to have_css('span.notifications:not([id])')
      end
    end

    context 'without a notification' do
      let(:notification) { false }

      it { is_expected.to have_no_css('span.notifications') }
    end
  end
end
