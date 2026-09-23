# frozen_string_literal: true

describe 'GroupeGestionnaire tiles', type: :component do
  let(:groupe_gestionnaire) { create(:groupe_gestionnaire, gestionnaires: [create(:gestionnaire)], administrateurs: [administrateur]) }
  let(:administrateur) { create(:administrateur) }

  describe GroupeGestionnaire::Card::GestionnairesComponent do
    subject { render_inline(described_class.new(groupe_gestionnaire:, path: '/gestionnaires', is_gestionnaire:)) }

    let(:is_gestionnaire) { true }

    it do
      is_expected.to have_link(href: '/gestionnaires', id: 'gestionnaires')
      is_expected.to have_css('p.fr-tag', text: '1')
      is_expected.to have_css('h3', exact_text: 'Gestionnaire')
      is_expected.to have_css('p.fr-btn', text: 'Modifier')
    end

    context 'for an administrateur' do
      let(:is_gestionnaire) { false }

      it { is_expected.to have_css('p.fr-btn', text: 'Voir') }
    end
  end

  describe GroupeGestionnaire::Card::AdministrateursComponent do
    subject { render_inline(described_class.new(groupe_gestionnaire:, path: '/administrateurs', is_gestionnaire:)) }

    let(:is_gestionnaire) { true }

    it do
      is_expected.to have_link(href: '/administrateurs', id: 'administrateurs')
      is_expected.to have_css('h3', exact_text: 'Administrateur')
      is_expected.to have_css('p.fr-btn', text: 'Modifier')
    end

    context 'for an administrateur' do
      let(:is_gestionnaire) { false }

      it { is_expected.to have_css('p.fr-btn', text: 'Voir') }
    end
  end

  describe GroupeGestionnaire::Card::ChildrenComponent do
    subject { render_inline(described_class.new(groupe_gestionnaire:, path: '/children')) }

    before { create_list(:groupe_gestionnaire, 2, parent: groupe_gestionnaire) }

    it 'has an id of its own' do
      is_expected.to have_link(href: '/children', id: 'children')
      is_expected.to have_css('p.fr-tag', text: '2')
      is_expected.to have_css('h3', exact_text: 'Groupes enfants')
    end
  end

  describe GroupeGestionnaire::Card::CommentairesComponent do
    subject { render_inline(described_class.new(groupe_gestionnaire:, administrateur:, path: '/commentaires', unread_commentaires:)) }

    let(:unread_commentaires) { false }

    it do
      is_expected.to have_link(href: '/commentaires', id: 'commentaires')
      is_expected.to have_css('p.fr-tag', text: '0')
      is_expected.to have_css('p.fr-btn', text: 'Voir')
      is_expected.to have_no_css('.notifications')
    end

    context 'with unread commentaires' do
      let(:unread_commentaires) { true }

      it 'shows a notification dot in the title' do
        is_expected.to have_css('h3 .notifications .fr-sr-only', text: 'notification')
      end
    end
  end
end
