# frozen_string_literal: true

describe LasuiteGaufreComponent, type: :component do
  subject { render_inline(described_class.new) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:administrateur_signed_in?).and_return(administrateur)
    allow_any_instance_of(ApplicationController).to receive(:instructeur_signed_in?).and_return(instructeur)
  end

  context 'when neither administrateur nor instructeur is signed in' do
    let(:administrateur) { false }
    let(:instructeur) { false }

    it 'does not render' do
      expect(subject.to_html).to be_empty
    end
  end

  context 'when signed in as instructeur' do
    let(:administrateur) { false }
    let(:instructeur) { true }

    it 'loads the v2 widget script and wires the controller to the services API' do
      expect(subject).to have_css("script[src='#{LasuiteGaufreComponent::WIDGET_SCRIPT_URL}']", visible: false)
      expect(subject).to have_css("[data-controller='lasuite-gaufre']")
      expect(subject.to_html).to include(LasuiteGaufreComponent::SERVICES_API_URL)
    end

    it 'initializes the widget with localized labels' do
      html = I18n.with_locale(:fr) { subject.to_html }
      expect(html).to include('Les services de La Suite numérique')
      expect(html).to include('Plus de services')
    end
  end
end
