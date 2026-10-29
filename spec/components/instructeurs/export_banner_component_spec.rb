# frozen_string_literal: true

RSpec.describe Instructeurs::ExportBannerComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:instructeur) { instructeurs.default }
  let(:procedure) { procedures.individual }
  let(:gi) { procedure.defaut_groupe_instructeur }
  let(:pro_connect) { false }

  def ready(export)
    export.file.attach(io: StringIO.new('x'), filename: 'e.csv')
    export.update!(job_status: :generated)
    export
  end

  around { |example| freeze_time { example.run } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:logged_in_with_pro_connect?).and_return(pro_connect)
    allow(instructeur).to receive(:export_for_banner).and_return(export)
    render_inline(described_class.new(instructeur:))
  end

  context 'without export' do
    let(:export) { nil }

    it 'renders an empty container' do
      expect(page).to have_css('#export-banner[tabindex="-1"]', visible: :all)
      expect(page).to have_no_css('#export-banner .alert')
    end

    it 'looks the export up without ProConnect when the session is not a ProConnect one' do
      expect(instructeur).to have_received(:export_for_banner).with(pro_connect: false)
    end

    context 'with a ProConnect session' do
      let(:pro_connect) { true }

      it { expect(instructeur).to have_received(:export_for_banner).with(pro_connect: true) }
    end
  end

  context 'with a pending export' do
    let(:export) { create(:export, :pending, format: :xlsx, groupe_instructeurs: [gi]) }

    it 'informs and polls' do
      expect(page).to have_css('.alert.alert-info[role="status"]', text: 'Votre dernier export est en cours de création.')
      expect(page).to have_link('liste des exports', href: exports_instructeur_procedure_path(export.procedure))
      expect(page).to have_css("[data-controller='turbo-poll'][data-turbo-poll-url-value='#{polling_instructeur_export_banner_path}'][data-turbo-poll-interval-value='5000']")
    end

    it 'identifies the banner by its export so a new export restarts the polling' do
      expect(page).to have_css("#export-banner > .alert#export-banner-#{export.id}")
    end

    it 'closes through a DELETE form' do
      expect(page).to have_css("form[action='#{instructeur_export_banner_path(export_id: export.id)}'] input[name='_method'][value='delete']", visible: :all)
      expect(page).to have_css('form[data-turbo="true"]', visible: :all)
      expect(page).to have_button('Masquer le message')
    end
  end

  context 'with a generated export whose file is not attached yet' do
    let(:export) { create(:export, :generated, groupe_instructeurs: [gi]) }

    it { expect(page).to have_css('.alert-info[data-controller="turbo-poll"]') }
  end

  context 'with an available export' do
    let(:export) { ready(create(:export, format: :xlsx, groupe_instructeurs: [gi])) }

    it 'offers the download without polling' do
      expect(page).to have_css('.alert.alert-success[role="status"]', text: 'Le dernier export au format xlsx est prêt.')
      expect(page).to have_link('télécharger', href: export.file.url)
      expect(page).to have_no_css('[data-controller="turbo-poll"]')
    end
  end

  context 'with a failed export' do
    let(:export) { create(:export, :failed, format: :xlsx, groupe_instructeurs: [gi]) }

    it 'warns without polling' do
      expect(page).to have_css('.alert.alert-danger[role="alert"]', text: 'Votre dernier export au format xlsx n’a pas pu être créé.')
      expect(page).to have_no_css('[data-controller="turbo-poll"]')
    end
  end
end
