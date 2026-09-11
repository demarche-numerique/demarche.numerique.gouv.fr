# frozen_string_literal: true

describe ProceduresController, type: :controller do
  describe "GET #logo" do
    subject { get :logo, params: { id: procedure.id } }

    context "without a logo" do
      let(:procedure) { create(:procedure) }

      it "redirects to the default logo" do
        expect(subject).to redirect_to(%r{/assets/.*republique-francaise-logo})
      end
    end

    # The variant is made by BlobProcessorJob; a request that lands before it must
    # not make one — this process may have no image library at all.
    context "with a logo whose variant is not made yet" do
      let(:procedure) { create(:procedure, :with_logo) }

      it "redirects to the logo itself and makes no variant" do
        expect { subject }.not_to change { ActiveStorage::VariantRecord.count }
        expect(subject).to redirect_to(%r{/rails/active_storage/blobs/})
      end
    end

    context "with a logo whose variant is made", :external_deps do
      let(:procedure) { create(:procedure, :with_logo) }

      before { procedure.logo.variant(resize_to_limit: [400, 400]).processed }

      it "redirects to the variant" do
        expect(subject).to redirect_to(%r{/rails/active_storage/representations/})
      end
    end
  end
end
