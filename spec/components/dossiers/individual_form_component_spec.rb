# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dossiers::IndividualFormComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:procedure) { create(:procedure, :published, :for_individual, no_gender: false) }
  let(:dossier) { create(:dossier, :with_individual, procedure:, user:) }

  subject { render_inline(described_class.new(dossier:)) }

  context "when user is connected via FranceConnect" do
    let(:user) { create(:user, :with_fci) }

    context "for self" do
      it "identity fields are disabled" do
        subject
        expect(page).to have_field("Prénom", disabled: true)
        expect(page).to have_field("Nom", disabled: true)
        expect(page).to have_css("input[name='dossier[individual_attributes][gender]'][disabled]")
        expect(page).to have_text("par FranceConnect et ne peuvent pas être modifiées")
      end
    end

    context "for self, when FranceConnect did not provide all identity fields" do
      let(:user) { create(:user, france_connect_informations: [build(:france_connect_information, family_name: nil)]) }

      it "all identity fields are editable" do
        subject
        expect(page).to have_field("Prénom", disabled: false)
        expect(page).to have_field("Nom", disabled: false)
        expect(page).not_to have_css("input[name='dossier[individual_attributes][gender]'][disabled]")
        expect(page).not_to have_text("par FranceConnect et ne peuvent pas être modifiées")
      end
    end

    context "for tiers" do
      let(:dossier) { create(:dossier, :for_tiers_without_notification, procedure:, user:) }

      it "mandataire fields are disabled" do
        subject
        within(".mandataire-infos") do
          expect(page).to have_field("Prénom", disabled: true)
          expect(page).to have_field("Nom", disabled: true)
        end
      end

      it "beneficiary identity fields are editable" do
        subject
        within(".individual-infos") do
          expect(page).to have_field("Prénom", disabled: false)
          expect(page).to have_field("Nom", disabled: false)
        end

        expect(page).to have_text("par FranceConnect et ne peuvent pas être modifiées")
      end
    end
  end

  context "when user is not connected via FranceConnect" do
    let(:user) { create(:user) }

    it "identity fields are editable" do
      subject
      expect(page).to have_field("Prénom", disabled: false)
      expect(page).to have_field("Nom", disabled: false)
      expect(page).not_to have_text("par FranceConnect et ne peuvent pas être modifiées")
    end
  end

  context "back button" do
    let(:user) { create(:user) }

    it "shows a back link to the procedure page" do
      subject
      expect(page).to have_link(I18n.t('views.users.dossiers.identite.back'), href: commencer_path(path: procedure.path))
    end
  end
end
