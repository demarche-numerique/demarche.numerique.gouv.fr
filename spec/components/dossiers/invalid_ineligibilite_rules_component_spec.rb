# frozen_string_literal: true

RSpec.describe Dossiers::InvalidIneligibiliteRulesComponent, type: :component do
  include Logic

  let(:procedure) do
    create(:procedure, :published, public_type_de_champs: [
      { type: :checkbox, libelle: 'certifie', stable_id: 1 },
      { type: :text, libelle: 'texte', stable_id: 2 },
    ])
  end
  let(:dossier) { create(:dossier, procedure:) }
  let(:checkbox) { dossier.root_champs_public.first }
  let(:texte) { dossier.root_champs_public.last }
  let(:updated_champ) { nil }
  let(:component) { described_class.new(dossier:, updated_champ:) }

  subject { render_inline(component).to_html }

  before do
    procedure.published_revision.update!(
      ineligibilite_enabled: true,
      ineligibilite_message: 'non éligible',
      ineligibilite_rules: ds_eq(Logic::ChampColumnValue.new(1, 'type_de_champ/1'), constant(false))
    )
  end

  context 'on a page render, the rules being met by the untouched checkbox' do
    let(:modal_html) { subject }

    it_behaves_like 'a labelled DSFR modal', 'modal-eligibilite-rules-dialog'

    it 'keeps its alertdialog semantics' do
      expect(Capybara.string(subject)).to have_css('dialog#modal-eligibilite-rules-dialog[role="alertdialog"][aria-describedby="modal-eligibilite-rules-description"][data-turbo-permanent]', visible: :all)
    end

    it 'renders the modal closed' do
      expect(dossier.can_passer_en_construction?).to be false
      expect(subject).to have_selector("[data-fr-opened='false']")
      expect(subject).to have_content('non éligible')
    end
  end

  context 'when the message holds line breaks, bold text and a link' do
    before do
      procedure.published_revision.update!(ineligibilite_message: "Première ligne\nSeconde **ligne**\n[aide](https://example.org/aide)")
    end

    it 'renders them in the description of the dialog' do
      description = render_inline(component).css('#modal-eligibilite-rules-description')

      expect(description.css('p').size).to eq(3)
      expect(description.css('strong').text).to eq('ligne')
      expect(description.css('a').attr('href').value).to eq('https://example.org/aide')
    end
  end

  context 'after the edit of a champ the rules do not read' do
    let(:updated_champ) { texte }

    it { is_expected.to have_selector("[data-fr-opened='false']") }
  end

  context 'after the edit of the checkbox the rules read' do
    let(:updated_champ) { checkbox }

    it { is_expected.to have_selector("[data-fr-opened='true']") }

    context 'when the edit made the dossier eligible' do
      before { checkbox.update!(value: 'true') }

      it { is_expected.to have_selector("[data-fr-opened='false']") }
    end
  end

  context 'when ineligibilite is disabled' do
    before { procedure.published_revision.update!(ineligibilite_enabled: false) }

    it { is_expected.to be_empty }
  end
end
