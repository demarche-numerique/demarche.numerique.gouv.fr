# frozen_string_literal: true

describe 'instructeur_mailer/send_notifications', type: :view do
  let(:instructeur) { create(:instructeur) }

  before do
    assign(:data, data)

    allow(Current).to receive(:application_name).and_return(APPLICATION_NAME)

    render
  end

  context 'when there is one dossier in contruction' do
    let(:data) do
      [
        {
          nb_en_construction: 1,
          nb_en_instruction: 0,
          nb_processed: 0,
          nb_accepted: 0,
          nb_refused: 0,
          nb_closed_without_continuation: 0,
          nb_dossiers_with_notifications: 0,
          nb_notifications: {},
          procedure_id: 213,
          procedure_libelle: 'une superbe démarche',
        },
      ]
    end

    it do
      expect(rendered).to have_link('une superbe démarche', href: instructeur_procedure_url(213))
      expect(rendered).to have_text('1 dossier en construction')
      expect(rendered).not_to have_text('notification')
    end
  end

  context 'when there is one dossier in instruction' do
    let(:data) do
      [
        {
          nb_en_construction: 0,
          nb_en_instruction: 1,
          nb_processed: 0,
          nb_accepted: 0,
          nb_refused: 0,
          nb_closed_without_continuation: 0,
          nb_dossiers_with_notifications: 0,
          nb_notifications: {},
          procedure_id: 213,
          procedure_libelle: 'une superbe démarche',
        },
      ]
    end

    it do
      expect(rendered).to have_link('une superbe démarche', href: instructeur_procedure_url(213))
      expect(rendered).to have_text('1 dossier en instruction')
      expect(rendered).not_to have_text('notification')
      expect(rendered).not_to have_text('construction')
      expect(rendered).not_to have_text('traité')
    end
  end

  context 'when there are three dossiers processed' do
    let(:data) do
      [
        {
          nb_en_construction: 0,
          nb_en_instruction: 0,
          nb_processed: 3,
          nb_accepted: 1,
          nb_refused: 1,
          nb_closed_without_continuation: 1,
          nb_dossiers_with_notifications: 0,
          nb_notifications: {},
          procedure_id: 213,
          procedure_libelle: 'une superbe démarche',
        },
      ]
    end

    it do
      expect(rendered).to have_link('une superbe démarche', href: instructeur_procedure_url(213))
      expect(rendered).to have_text('3 dossiers')
      expect(rendered).to have_text('(1 accepté, 1 refusé, 1 classé sans suite)')
      expect(rendered).not_to have_text('notification')
      expect(rendered).not_to have_text('construction')
      expect(rendered).not_to have_text('instruction')
    end
  end

  context 'when there is notifications' do
    let(:data) do
      [
        {
          nb_en_construction: 1,
          nb_en_instruction: 0,
          nb_processed: 0,
          nb_accepted: 0,
          nb_refused: 0,
          nb_closed_without_continuation: 0,
          nb_dossiers_with_notifications: 1,
          nb_notifications: { 'dossier_modifie' => 1 },
          procedure_id: 213,
          procedure_libelle: 'une superbe démarche',
        },
      ]
    end

    it do
      expect(rendered).to have_text("1 dossier avec des notifications « nouveautés »")
      expect(rendered).to have_text("1 « DOSSIER MODIFIÉ »")
    end
  end
end
