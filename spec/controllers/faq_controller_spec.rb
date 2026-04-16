# frozen_string_literal: true

RSpec.describe FAQController, type: :controller do
  before { Rails.cache.clear }
  describe "GET #index" do
    render_views

    it "displays titles and render links for all entries" do
      get :index

      # Usager
      expect(response.body).to include("Gestion de mon compte")
      expect(response.body).to include("Je veux changer mon adresse électronique")
      expect(response.body).to include(faq_path(category: "usager", slug: "je-veux-changer-mon-adresse-email"))

      # Instructeur
      expect(response.body).to include("Je dois confirmer mon compte à chaque connexion")

      # Instructeur
      expect(response.body).to include("Les blocs répétables")
    end

    context "with invalid subcategory" do
      before do
        service = instance_double(FAQsLoaderService, all: faqs)
        allow(FAQsLoaderService).to receive(:new).and_return(service)
      end

      let(:faqs) do
        {
          'usager' => {
            'oops' => [{ category: 'usager', subcategory: 'oops', title: 'FAQ Title 1', slug: 'faq1' }],
          },
        }
      end

      it "fails so we can't make a typo and publish non translated subcategories" do
        expect { get :index }.to raise_error(ActionView::Template::Error)
      end
    end
  end

  describe "GET #show" do
    before do
      allow(Current).to receive(:application_name).and_return('demarche.numerique.gouv.fr')
    end

    render_views

    context "when the FAQ exists" do
      it "renders the show template with the FAQ content and metadata" do
        get :show, params: { category: 'usager', slug: 'je-veux-changer-mon-adresse-email' }
        expect(response.body).to include('Si vous disposez d’un compte usager sur demarche.numerique.gouv.fr')

        # link to siblings
        expect(response.body).to include(faq_path(category: 'usager', slug: 'je-veux-changer-mon-mot-de-passe'))
      end
    end

    context "when the FAQ does not exist" do
      it "raises a routing error for a missing FAQ" do
        expect {
          get :show, params: { category: 'nonexistent', slug: 'nofaq' }
        }.to raise_error(ActionController::RoutingError)
      end
    end
  end
end
