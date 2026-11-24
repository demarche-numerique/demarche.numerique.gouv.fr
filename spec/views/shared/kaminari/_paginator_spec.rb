# frozen_string_literal: true

describe 'shared/kaminari/_paginator', type: :view do
  let(:collection) { Kaminari.paginate_array((1..200).to_a).page(current_page).per(10) }

  subject { view.paginate(collection, views_prefix: 'shared', params: { controller: 'users/dossiers', action: 'index' }) }

  context 'on a middle page' do
    let(:current_page) { 10 }

    it 'renders the full DSFR pagination' do
      expect(subject).to have_css('nav.fr-pagination[role="navigation"][aria-label="Pagination"] ul.fr-pagination__list')
      expect(subject).to have_link('Premier', class: 'fr-pagination__link--first', title: 'Première page')
      expect(subject).to have_link('Précédent', class: 'fr-pagination__link--prev')
      expect(subject).to have_link('9', title: 'Page 9')
      expect(subject).to have_css('a.fr-pagination__link[aria-current="page"][title="Page 10"]:not([href])', text: '10')
      expect(subject).to have_link('...', href: '#', class: 'fr-displayed-lg')
      expect(subject).to have_link('Suivant', class: 'fr-pagination__link--next')
      expect(subject).to have_link('Dernier', class: 'fr-pagination__link--last', title: 'Dernière page')
    end
  end

  context 'on the first page' do
    let(:current_page) { 1 }

    it 'hides the first and previous links' do
      expect(subject).not_to have_css('.fr-pagination__link--first, .fr-pagination__link--prev')
      expect(subject).to have_link('Suivant')
    end
  end
end
