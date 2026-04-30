# frozen_string_literal: true

describe 'shared/_procedure_description', type: :view do
  let(:estimated_duration_visible) { true }
  let(:procedure) { create(:procedure, :published, :with_service, estimated_duration_visible:) }

  subject { render partial: 'shared/procedure_description', locals: { procedure: procedure } }

  it 'renders the view' do
    subject
    expect(rendered).to have_selector('.procedure-logos')
    expect(rendered).to have_text(procedure.libelle)
    expect(rendered).to have_text(procedure.description)
    expect(rendered).to have_text('Temps de remplissage estimé')
    expect(rendered).not_to have_text('Quelles sont les pièces justificatives à fournir')
    expect(rendered).not_to have_text('Qu’est-ce que le cadre législatif « silence vaut accord » ?')
  end

  context 'procedure with estimated duration not visible' do
    let(:estimated_duration_visible) { false }
    it 'hides the estimated duration' do
      subject
      expect(rendered).not_to have_text('Temps de remplissage estimé')
    end
  end

  it 'does not show empty date limite' do
    subject
    expect(rendered).not_to have_text('Date limite')
  end

  context 'when the procedure has an auto_archive date' do
    let(:procedure) { create(:procedure, :published, :with_service, :with_auto_archive) }
    it 'shows the auto_archive_on' do
      subject
      expect(rendered).to have_text('Date limite')
    end
  end

  context 'when procedure has notice' do
    let(:procedure) { create(:procedure, :published, :with_notice) }
    before do
      allow(view).to receive(:administrateur_signed_in?).and_return(false)
    end

    it 'shows a link to the notice' do
      subject
      expect(rendered).to have_link("Télécharger le guide de la démarche")
    end
  end

  context 'when procedure has usual_traitement_time' do
    before do
      allow(procedure).to receive(:stats_usual_traitement_time).and_return([1.day, 1.day, 1.day])
    end

    it 'shows a usual traitement text' do
      subject
      expect(rendered).to have_text("Quels sont les délais d’instruction pour cette démarche ?")
      expect(rendered).to have_text("Dans le meilleur des cas, le délai d’instruction est : 1 jour.")
    end
  end

  context 'when the procedure has pieces jointes' do
    let(:procedure) { create(:procedure, :draft, types_de_champ_public: [{ type: :piece_justificative, nature: 'titre_identite' }, { type: :piece_justificative }, { type: :siret }]) }
    it 'shows the pieces jointes list for draft procedure' do
      subject
      expect(rendered).to have_text('Quelles sont les pièces justificatives à fournir')
      expect(rendered).to have_text('Libelle du champ')
      expect(rendered).to have_selector('.pieces_jointes ul li', count: 2)
    end

    it 'shows the pieces jointes list for published procedure' do
      procedure.publish!(procedure.administrateurs.first)
      subject
      expect(rendered).to have_text('Quelles sont les pièces justificatives à fournir')
      expect(rendered).to have_text('Libelle du champ')
      expect(rendered).to have_selector('.pieces_jointes ul li', count: 2)
    end

    it 'shows the manual description pieces jointes list if admin filled one' do
      procedure.update!(description_pj: 'une description des pj manuelle')
      subject
      expect(rendered).to have_text('Quelles sont les pièces justificatives à fournir')
      expect(rendered).to have_text('une description des pj manuelle')
    end
  end

  context 'when the procedure is sva' do
    before { travel_to Time.zone.local(2023, 1, 1) }
    let(:procedure) { create(:procedure, :published, :sva) }

    it 'shows an explanation text' do
      subject
      expect(rendered).to have_text('Cette démarche applique le « Silence Vaut Accord »')
      expect(rendered).to have_text('dans les 2 mois')
      expect(rendered).to have_text("2 mars 2023")
    end

    context 'when unit is weeks' do
      before {
        procedure.sva_svr["unit"] = "weeks"
      }

      it 'shows an human period' do
        subject
        expect(rendered).to have_text('dans les 2 semaines')
        expect(rendered).to have_text("16 janvier 2023")
      end
    end
  end

  context 'caching', caching: true do
    it "works" do
      expect(procedure).to receive(:public_wrapped_partionned_pjs).once
      2.times { render partial: 'shared/procedure_description', locals: { procedure: } }
    end

    it 'cache_key depends of revision' do
      render partial: 'shared/procedure_description', locals: { procedure: }
      expect(rendered).not_to have_text('new pj')

      travel(1.minute)

      procedure.draft_revision.add_type_de_champ(type_champ: :piece_justificative, libelle: 'new pj')
      procedure.publish_revision!(procedure.administrateurs.first)

      render partial: 'shared/procedure_description', locals: { procedure: }
      expect(rendered).to have_text('new pj')
    end

    context 'draft procedure' do
      let(:procedure) { create(:procedure, :draft) }

      it 'respect revision changes on brouillon' do
        render partial: 'shared/procedure_description', locals: { procedure: }
        expect(rendered).not_to have_text('new pj')

        procedure.draft_revision.add_type_de_champ(type_champ: :piece_justificative, libelle: 'new pj')

        render partial: 'shared/procedure_description', locals: { procedure: }
        expect(rendered).to have_text('new pj')
      end
    end
  end
end
