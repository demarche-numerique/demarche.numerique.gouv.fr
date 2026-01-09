# frozen_string_literal: true

describe Instructeurs::ExportTemplatesController, type: :controller do
  before { sign_in(instructeur.user) }

  let(:instructeur) { create(:instructeur) }
  let(:procedure) do
    create(
      :procedure, instructeurs: [instructeur],
      types_de_champ_public: [{ type: :piece_justificative, libelle: "pj1", stable_id: 3 }]
    )
  end
  let(:groupe_instructeur) { procedure.defaut_groupe_instructeur }
  let(:groupe_instructeur_id) { groupe_instructeur.id }

  let(:export_template_params) do
    {
      name: "coucou",
      kind: "zip",
      groupe_instructeur_id:,
      export_pdf:,
      dossier_folder: item_params(text: "DOSSIER_"),
      attestation: item_params(text: "attestation"),
      pjs: [pj_item_params(stable_id: 3, text: "avis-commission-"), pj_item_params(stable_id: 666, text: "evil-hack")],
    }
  end

  let(:export_pdf) { item_params(text: "mon_export_") }

  describe '#new' do
    subject { get :new, params: { procedure_id: procedure.id } }

    it do
      subject
      expect(assigns(:export_template)).to be_present
      expect(assigns(:preview_service)).to be_a(DossierPreviewService)
    end
  end

  describe '#create' do
    let(:create_params) { export_template_params }
    subject { post :create, params: { procedure_id: procedure.id, export_template: create_params } }

    context 'with valid params' do
      it 'works' do
        subject
        expect(response).to redirect_to(export_templates_instructeur_procedure_path(procedure))
        expect(flash.notice).to eq "Le modèle d’export coucou a bien été créé"
        expect(ExportTemplate.last.pjs).not_to be_blank
        expect(ExportTemplate.last.commentaires_attachments).to be_falsey
        expect(ExportTemplate.last.avis_attachments).to be_falsey
        expect(ExportTemplate.last.justificatif_motivation).to be_falsey
      end
    end

    context 'with invalid params' do
      let(:export_pdf) do
        item_params(text: 'toto').merge("template" => { "content" => [{ "content" => "invalid" }] }.to_json)
      end

      it 'display error notification' do
        subject
        expect(flash.alert).to be_present
      end
    end

    context 'with attachments checked' do
      let(:create_params) { export_template_params.merge({ commentaires_attachments: 1, avis_attachments: 1, justificatif_motivation: 1 }) }

      it 'works' do
        subject
        expect(ExportTemplate.last.commentaires_attachments).to be_truthy
        expect(ExportTemplate.last.avis_attachments).to be_truthy
        expect(ExportTemplate.last.justificatif_motivation).to be_truthy
      end
    end

    context 'with procedure not accessible by current instructeur' do
      let(:another_procedure) { create(:procedure) }
      subject { post :create, params: { procedure_id: another_procedure.id, export_template: export_template_params } }

      it 'raise exception' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with invalid groupe_instructeur_id' do
      let(:groupe_instructeur_id) { create(:groupe_instructeur).id }

      it 'display error notification' do
        expect { subject }.not_to change(ExportTemplate, :count)
        expect(flash.alert).to be_present
      end
    end

    context 'without pjs' do
      let(:create_params) { export_template_params.tap { _1.delete(:pjs) } }

      it 'works' do
        subject

        expect(flash.notice).to eq "Le modèle d’export coucou a bien été créé"
        expect(ExportTemplate.last.pjs).to match_array([])
      end
    end

    context 'with tabular params' do
      let(:procedure) do
        create(
          :procedure, instructeurs: [instructeur],
          types_de_champ_public: [{ type: :text, libelle: 'un texte', stable_id: 1 }]
        )
      end

      let(:exported_columns) do
        [
          { id: procedure.find_column(label: 'Demandeur').id, libelle: 'Demandeur' },
          { id: procedure.find_column(label: 'Date du dernier évènement').id, libelle: 'Date du dernier évènement' },
        ].map(&:to_json)
      end

      let(:create_params) do
        {
          name: "ExportODS",
          kind: "ods",
          groupe_instructeur_id: groupe_instructeur.id,
          export_pdf: item_params(text: "export"),
          dossier_folder: item_params(text: "dossier"),
          attestation: item_params(text: "attestation"),
          exported_columns:,
        }
      end

      context 'with valid params' do
        it 'redirect to some page' do
          subject
          expect(response).to redirect_to(export_templates_instructeur_procedure_path(procedure))
          expect(flash.notice).to eq "Le modèle d’export ExportODS a bien été créé"
          expect(ExportTemplate.last.exported_columns.map(&:libelle)).to match_array ['Demandeur', 'Date du dernier évènement']
        end
      end
    end
  end

  describe '#edit' do
    let(:export_template) { create(:export_template, groupe_instructeur:) }
    subject { get :edit, params: { procedure_id: procedure.id, id: export_template.id } }

    it 'render edit' do
      subject
      expect(response).to render_template(:edit)
      expect(assigns(:preview_service)).to be_a(DossierPreviewService)
    end

    context "with export_template not accessible by current instructeur" do
      let(:another_groupe_instructeur) { create(:groupe_instructeur) }
      let(:export_template) { create(:export_template, groupe_instructeur: another_groupe_instructeur) }

      it 'raise exception' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#update' do
    let(:export_template) { create(:export_template, groupe_instructeur:) }
    let(:export_pdf) { item_params(text: "exPort_") }

    subject { put :update, params: { procedure_id: procedure.id, id: export_template.id, export_template: export_template_params } }

    context 'with valid params' do
      it 'redirect to some page' do
        subject
        expect(response).to redirect_to(export_templates_instructeur_procedure_path(procedure))
        expect(flash.notice).to eq "Le modèle d’export coucou a bien été modifié"

        export_template.reload

        expect(export_template.export_pdf.template_json).to eq(item_params(text: "exPort_")["template"])
        expect(export_template.pjs.map(&:template_json)).to eq([item_params(text: "avis-commission-")["template"]])
      end
    end

    context 'with invalid params' do
      let(:export_pdf) do
        item_params(text: 'a').merge("template" => { "content" => [{ "content" => "invalid" }] }.to_json)
      end

      it 'display error notification' do
        subject
        expect(flash.alert).to be_present
      end
    end

    context 'with invalid groupe_instructeur_id' do
      let(:groupe_instructeur_id) { create(:groupe_instructeur).id }

      it 'display error notification' do
        subject
        expect(export_template.export_pdf.template_json).not_to eq(item_params(text: "exPort_")["template"])
        expect(flash.alert).to be_present
      end
    end

    context 'for tabular' do
      let(:exported_columns) do
        [
          { id: procedure.find_column(label: 'Demandeur').id, libelle: 'Demandeur' },
          { id: procedure.find_column(label: 'Date du dernier évènement').id, libelle: 'Date du dernier évènement' },
        ].map(&:to_json)
      end

      let(:export_template_params) do
        {
          name: "ExportODS",
          kind: "ods",
          groupe_instructeur_id: groupe_instructeur.id,
          export_pdf: item_params(text: "export"),
          dossier_folder: item_params(text: "dossier"),
          attestation: item_params(text: "attestation"),
          exported_columns:,
        }
      end

      context 'with valid params' do
        it 'redirect to some page' do
          subject
          expect(response).to redirect_to(export_templates_instructeur_procedure_path(procedure))
          expect(flash.notice).to eq "Le modèle d’export ExportODS a bien été modifié"
          expect(ExportTemplate.last.exported_columns.map(&:libelle)).to match_array ['Demandeur', 'Date du dernier évènement']
        end
      end
    end
  end

  describe '#destroy' do
    let(:export_template) { create(:export_template, groupe_instructeur:) }
    subject { delete :destroy, params: { procedure_id: procedure.id, id: export_template.id } }

    context 'with valid params' do
      it 'redirect to some page' do
        subject
        expect(response).to redirect_to(export_templates_instructeur_procedure_path(procedure))
        expect(flash.notice).to eq "Le modèle d’export Mon export a bien été supprimé"
      end
    end
  end

  describe '#preview' do
    render_views

    let(:export_template) { create(:export_template, groupe_instructeur:) }

    context 'with put request' do
      subject { put :preview, params: { procedure_id: procedure.id, id: export_template.id, export_template: export_template_params }, format: :turbo_stream }

      it 'works with bigbig procedure' do
        dossier = DossierPreviewService.new(procedure:, current_user: instructeur.user).dossier
        subject
        expect(response.body).to include "DOSSIER_#{dossier.id}"
        expect(response.body).to include "mon_export_#{dossier.id}.pdf"
      end
    end
  end

  def pj_item_params(stable_id:, text:, enabled: true)
    item_params(text: text, enabled: enabled).merge("stable_id" => stable_id.to_s)
  end

  def item_params(text:, enabled: true)
    {
      "enabled" => enabled,
      "template" => {
        "type" => "doc",
        "content" => content(text:),
      }.to_json,
    }
  end

  def content(text:)
    [
      {
        "type" => "paragraph",
        "content" => [
          { "text" => text, "type" => "text" },
          { "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } },
        ],
      },
    ]
  end
end
