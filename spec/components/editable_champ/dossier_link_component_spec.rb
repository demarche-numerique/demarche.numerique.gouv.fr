# frozen_string_literal: true

describe EditableChamp::DossierLinkComponent, type: :component do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:user) { dossier.user }
  let(:tdc) { procedure.active_revision.type_de_champs.first }
  let(:champ) { dossier.champs.first }

  subject(:render) do
    component = nil
    ActionView::Base.empty.form_for(champ, url: '/') do |form|
      component = EditableChamp::EditableChampComponent.new(champ:, form:)
    end

    render_inline(component)
  end

  context 'when the admin did not limit procedures' do
    it 'renders a free numeric text input' do
      render

      expect(page).to have_css('input[type="text"]')
      expect(page).not_to have_css('select')
      expect(page).not_to have_css('react-component')
    end
  end

  describe 'the field hint' do
    context 'when the admin did not limit procedures' do
      it 'invites the user to type a dossier number' do
        render

        expect(page).to have_text('Format attendu')
      end
    end

    context 'when the admin limited the field and the user has a dossier to propose' do
      let(:linked_procedure) { create(:procedure) }

      before do
        tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [linked_procedure.id])
        create(:dossier, :en_construction, procedure: linked_procedure, user:)
      end

      it 'invites the user to select a dossier' do
        render

        expect(page).to have_text('Sélectionnez le numéro')
      end
    end

    context 'when the admin limited the field but the user has no dossier to propose' do
      before { tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [create(:procedure).id]) }

      it 'keeps the free-text format hint' do
        render

        expect(page).to have_text('Format attendu')
      end
    end
  end

  context 'when the admin limited the field to some procedures' do
    let(:linked_procedure) { create(:procedure, libelle: 'Démarche A') }

    before { tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [linked_procedure.id]) }

    context 'with fewer than 20 dossiers submitted by the user' do
      let!(:user_dossier) { create(:dossier, :en_construction, procedure: linked_procedure, user:) }
      let!(:other_user_dossier) { create(:dossier, :en_construction, procedure: linked_procedure) }
      let!(:brouillon) { create(:dossier, procedure: linked_procedure, user:) }

      it 'renders a grouped select with only the dossiers submitted by the user' do
        render

        expect(page).to have_css('select optgroup[label*="Démarche A"]')
        expect(page).to have_css("select option[value='#{user_dossier.id}']")
        expect(page).not_to have_css("select option[value='#{other_user_dossier.id}']")
        expect(page).not_to have_css("select option[value='#{brouillon.id}']")
      end
    end

    context 'with an expired dossier submitted by the user' do
      let!(:expired_dossier) { create(:dossier, :en_construction, :hidden_by_expired, procedure: linked_procedure, user:) }

      it 'offers it with an option label mentioning its expiration date' do
        render

        expect(page).to have_css("select option[value='#{expired_dossier.id}']", text: /expiré le/)
      end
    end

    context 'with an expired dossier already purged (DeletedDossier)' do
      let!(:purged_dossier) do
        create(:deleted_dossier, reason: :expired, user_id: user.id, procedure: linked_procedure,
                                 dossier_id: 99_999, depose_at: 3.days.ago.to_date)
      end

      it 'offers it with an option label mentioning its expiration date' do
        render

        expect(page).to have_css("select option[value='#{purged_dossier.dossier_id}']", text: /expiré le/)
      end
    end

    context 'when the user has no dossier to propose on any allowed procedure' do
      it 'falls back to the free numeric text input' do
        render

        expect(page).to have_css('input[type="text"]')
        expect(page).not_to have_css('select')
      end
    end

    context 'when the user has a dossier on one allowed procedure but not another' do
      let(:empty_procedure) { create(:procedure, libelle: 'Démarche B') }

      before do
        tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [linked_procedure.id, empty_procedure.id])
        create(:dossier, :en_construction, procedure: linked_procedure, user:)
      end

      it 'renders a disabled option for the procedure without any dossier' do
        render

        expect(page).to have_css('select optgroup[label*="Démarche B"] option[disabled]', text: 'Vous n’avez déposé aucun dossier sur cette démarche.')
      end
    end

    context 'with at least the autocomplete threshold of dossiers' do
      let!(:user_dossier) { create(:dossier, :en_construction, procedure: linked_procedure, user:) }

      before { stub_const("#{described_class}::THRESHOLD_NB_OPTIONS_AS_AUTOCOMPLETE", 1) }

      it 'renders a filterable react select grouped by procedure' do
        render

        expect(page).to have_css('react-component[name="Select/SingleSelect"]')
        expect(page).not_to have_css('select')

        props = JSON.parse(page.find('react-component')['props'])
        expect(props['sections'].first['label']).to eq('Démarche « Démarche A »')
        expect(props['sections'].first['items'].map { it['value'] }).to eq([user_dossier.id.to_s])
        # the select trigger gets its accessible name from the field label
        expect(props['label_id']).to be_present
      end

      context 'when the user has no dossier on another allowed procedure' do
        let(:empty_procedure) { create(:procedure, libelle: 'Démarche B') }

        before { tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [linked_procedure.id, empty_procedure.id]) }

        it 'renders an unselectable item for the procedure without any dossier' do
          render

          props = JSON.parse(page.find('react-component')['props'])
          empty_section = props['sections'].last
          expect(empty_section['label']).to eq('Démarche « Démarche B »')
          expect(empty_section['items'].map { it['label'] }).to eq(['Vous n’avez déposé aucun dossier sur cette démarche.'])
          expect(props['disabled_keys']).to eq(empty_section['items'].map { it['value'] })
        end
      end
    end

    context 'when the current dossier itself belongs to an allowed procedure' do
      let(:dossier) { create(:dossier, :en_construction, procedure:) }
      let!(:sibling_dossier) { create(:dossier, :en_construction, procedure:, user:) }

      before { tdc.update!(procedures_limit: '1', dossier_link_procedure_ids: [procedure.id]) }

      it 'does not offer the current dossier as a link target' do
        render

        expect(page).to have_css("select option[value='#{sibling_dossier.id}']")
        expect(page).not_to have_css("select option[value='#{dossier.id}']")
      end
    end
  end
end
