# frozen_string_literal: true

describe AccountDropdownComponent, type: :component do
  let(:component) { described_class.new(dossier:, nav_bar_profile:) }
  let(:dossier) { nil }
  let(:nav_bar_profile) { :user }
  let(:user) { build(:user) }

  subject { render_inline(component) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:super_admin_signed_in?).and_return(false)
  end

  describe 'basic display' do
    it 'shows user email' do
      expect(subject).to have_text(user.email)
    end

    context 'when guest profile' do
      let(:nav_bar_profile) { :guest }
      let(:user) { nil }

      it 'does not show profile badge' do
        expect(subject).not_to have_css('.fr-badge')
      end
    end
  end

  describe 'profile switching' do
    context 'when user profile' do
      let(:nav_bar_profile) { :user }

      before do
        allow_any_instance_of(ApplicationController).to receive(:instructeur_signed_in?).and_return(true)
      end

      it 'shows instructor switch option' do
        expect(subject).to have_link('Passer en instructeur')
        expect(subject).not_to have_link('Passer en usager')
      end
    end

    context 'when instructor profile' do
      let(:nav_bar_profile) { :instructeur }

      before do
        allow_any_instance_of(ApplicationController).to receive(:instructeur_signed_in?).and_return(true)
      end

      it 'shows user switch option' do
        expect(subject).to have_link('Passer en usager')
        expect(subject).not_to have_link('Passer en instructeur')
      end
    end
  end

  context 'when in procedures controller' do
    before do
      allow_any_instance_of(ApplicationController).to receive(:instructeur_signed_in?).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:controller_name).and_return('procedures')
    end

    context 'with procedure id' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:params)
          .and_return({ id: '123' })
      end

      it 'links to specific procedure for instructor' do
        expect(subject.to_html).to include('/procedures/123')
      end
    end
  end

  context 'when user is france connected' do
    subject { render_inline(component) }

    before do
      user.france_connect_informations << build(:france_connect_information, user:)
    end

    it 'shows FranceConnect badge' do
      expect(subject).to have_text('via FranceConnect')
    end
  end
end
