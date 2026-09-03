# frozen_string_literal: true

describe 'shared/dossiers/champs', type: :view do
  let(:instructeur) { create(:instructeur) }
  let(:demande_seen_at) { nil }
  let(:profile) { "instructeur" }
  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
  let(:type_de_champs) { dossier.revision.public_root_type_de_champs }

  before do
    view.extend DossierHelper
    view.extend DossierLinkHelper

    if profile == "instructeur"
      allow(view).to receive(:current_instructeur).and_return(instructeur)
    end
  end

  subject { render ViewableChamp::SectionComponent.new(type_de_champs:, dossier:, demande_seen_at:, profile:) }

  context "there are some champs" do
    let(:public_type_de_champs) { [{ type: :checkbox }, { type: :header_section }, { type: :explication }, { type: :dossier_link }, { type: :textarea }, { type: :integer_number }] }
    let(:champ1) { dossier.root_champs_public[0] }
    let(:champ2) { dossier.root_champs_public[1] }
    let(:champ3) { dossier.root_champs_public[2] }
    let(:champ4) { dossier.root_champs_public[3] }
    let(:champ5) { dossier.root_champs_public[4] }
    let(:champ6) { dossier.root_champs_public[5] }

    before do
      champ1.update(value: 'true')
      champ4.update(value: dossier.id)
      champ5.update(value: "Some long text in a textarea.")
      champ6.update(value: 123)
    end

    it "renders titles and values of champs" do
      expect(subject).to include(champ1.libelle)
      expect(subject).to include('Oui')

      expect(subject).to have_css(".header-section")
      expect(subject).to include(champ2.libelle)

      expect(subject).to have_text(dossier.text_summary)

      expect(subject).to include(champ5.libelle)
      expect(subject).to include(champ5.value)
      expect(subject).to include(champ6.libelle)
      expect(subject).to include(champ6.value)
    end

    it "doesn't render explication champs" do
      expect(subject).not_to include(champ3.libelle)
    end
  end

  context "with auto-link" do
    let(:public_type_de_champs) { [{ type: :text }, { type: :textarea }] }
    let(:champ1) { dossier.root_champs_public.first }
    let(:champ2) { dossier.root_champs_public.second }

    before do
      champ1.update(value: 'https://github.com/tchak')
      champ2.update(value: "https://github.com/LeSim")
    end

    let(:link1) { '<a href="https://github.com/tchak" target="_blank" rel="noopener">https://github.com/tchak</a>' }
    let(:link2) { '<a href="https://github.com/LeSim" target="_blank" rel="noopener">https://github.com/LeSim</a>' }

    it "render links" do
      expect(subject).to include(link1)
      expect(subject).to include(link2)
    end
  end

  context "with a dossier champ, but we are not authorized to acces the dossier" do
    let(:public_type_de_champs) { [{ type: :dossier_link }] }

    before do
      dossier.champ_data.first.update(value: dossier.id)
    end

    it "renders the no-access modal trigger" do
      is_expected.to have_link("Dossier n° #{dossier.id}", href: "#modal-no-access-to-dossier-#{dossier.id}")
      is_expected.to have_text("Vous n’avez pas accès à ce dossier")
      is_expected.to have_text(dossier.text_summary)
    end

    it "emphasizes only the procedure and organisme names in the summary" do
      is_expected.to have_css("strong", text: dossier.procedure.libelle)
      is_expected.to have_css("strong", text: dossier.procedure.organisation_name)
      is_expected.to have_no_css("strong", text: "Dossier déposé le")
    end
  end

  context "with a dossier champ pointing to a deposited dossier" do
    let(:public_type_de_champs) { [{ type: :dossier_link }] }

    before do
      dossier.champs.first.update(value: linked_dossier.id)
    end

    context "when the viewer has access to the linked dossier" do
      let(:linked_dossier) { create(:dossier, :en_construction, procedure: create(:procedure, instructeurs: [instructeur])) }

      it "renders the enriched summary with the procedure in bold" do
        is_expected.to have_css("strong", text: linked_dossier.procedure.libelle)
        is_expected.to include("N° #{linked_dossier.id}")
      end
    end

    context "when the instructeur has no access to the linked dossier" do
      let(:linked_dossier) { create(:dossier, :en_construction) }

      it "renders the no-access component instead of the summary" do
        is_expected.to have_css("#modal-no-access-to-dossier-#{linked_dossier.id}", visible: false)
      end
    end
  end

  context "with a dossier_link champ but without value" do
    let(:public_type_de_champs) { [{ type: :dossier_link, mandatory: false }] }

    before do
      dossier.champ_data.first.update(value: nil)
    end

    it { is_expected.not_to include("non saisi") }

    context 'when profile is usager' do
      let(:profile) { "usager" }
      it { is_expected.to include("non saisi (facultatif)") }
    end
  end

  context "with a piece justificative without value" do
    let(:public_type_de_champs) { [{ type: :piece_justificative, mandatory: false }] }

    before do
      dossier.champ_data.first.piece_justificative_file.purge
    end

    it { is_expected.not_to include("pièce justificative non saisie") }

    context 'when profile is usager' do
      let(:profile) { "usager" }
      it { is_expected.to include("pièce justificative non saisie (facultative)") }
    end
  end

  context "with seen_at" do
    let(:public_type_de_champs) { [{ type: :checkbox }] }
    let(:dossier) { create(:dossier, :en_construction, :with_populated_champs, procedure:, depose_at: 1.day.ago.change(usec: 0)) }
    let(:champ1) { dossier.champ_data.first }

    context "with a demande_seen_at after champ updated_at" do
      let(:demande_seen_at) { champ1.updated_at + 1.hour }

      it { is_expected.not_to have_css(".fr-badge--new") }
    end

    context "with a demande_seen_at before champ updated_at" do
      let(:demande_seen_at) { champ1.updated_at - 1.hour }

      it { is_expected.to have_css(".fr-badge--new") }
    end

    context "with champ updated_at at depose_at" do
      let(:demande_seen_at) { champ1.updated_at - 1.hour }

      before do
        champ1.update_columns(value: 'false', updated_at: dossier.depose_at)
      end

      it { is_expected.not_to have_css(".fr-badge--new") }
    end
  end
end
