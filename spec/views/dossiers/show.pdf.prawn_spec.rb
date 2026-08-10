# frozen_string_literal: true

describe 'dossiers/show.pdf', :external_deps, type: :view do
  PDFTOTEXT_AVAILABLE = system('which pdftotext > /dev/null 2>&1') unless defined?(PDFTOTEXT_AVAILABLE)

  def render_and_extract(dossier, procedure, scenario_label)
    assign(:dossier, dossier)
    assign(:acls, PiecesJustificativesService.new(user_profile: dossier.user, export_template: nil).acl_for_dossier_export(procedure))
    render template: 'dossiers/show', formats: [:pdf]

    pdf_path = Rails.root.join("tmp/test_show_#{scenario_label}.pdf")
    File.binwrite(pdf_path, rendered)
    `pdftotext -layout #{pdf_path} - 2>/dev/null`
  end

  describe 'nested hierarchy (level 1/2/3)' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :header_section, libelle: 'Identité', level: 1 },
        { type: :header_section, libelle: 'État civil', level: 2 },
        { type: :text, libelle: 'Nom' },
        { type: :header_section, libelle: 'Détail', level: 3 },
        { type: :text, libelle: 'Prénom' },
        { type: :header_section, libelle: 'Coordonnées', level: 2 },
        { type: :text, libelle: 'Email' },
        { type: :header_section, libelle: 'Justificatifs', level: 1 },
        { type: :header_section, libelle: "Pièce d'identité", level: 2 },
        { type: :text, libelle: 'Numéro' },
      ])
    end

    let(:dossier) do
      d = create(:dossier, :en_construction, procedure: procedure)
      d.root_public_champs.find { _1.libelle == 'Nom' }&.update(value: 'Dupont')
      d.root_public_champs.find { _1.libelle == 'Prénom' }&.update(value: 'Jean')
      d.root_public_champs.find { _1.libelle == 'Email' }&.update(value: 'jean.dupont@example.fr')
      d.root_public_champs.find { _1.libelle == 'Numéro' }&.update(value: 'AB123456')
      d
    end

    it 'renders without error' do
      expect { render_and_extract(dossier, procedure, 'hierarchy') }.not_to raise_error
      expect(rendered).to start_with('%PDF')
    end

    it 'numbers and indents hierarchically', if: PDFTOTEXT_AVAILABLE do
      text = render_and_extract(dossier, procedure, 'hierarchy')
      expect(text).to include('1. Identité')
      expect(text).to include('1.1. État civil')
      expect(text).to include('1.1.1. Détail')
      expect(text).to include('1.2. Coordonnées')
      expect(text).to include('2. Justificatifs')
      expect(text).to include("2.1. Pièce d'identité")
    end
  end

  describe 'private (instructeur) header sections' do
    let(:instructeur) { create(:instructeur) }
    let(:procedure) do
      create(:procedure, :published,
        types_de_champ_public: [{ type: :text, libelle: 'Question publique' }],
        types_de_champ_private: [
          { type: :header_section, libelle: 'Notes', level: 1 },
          { type: :header_section, libelle: 'Vérifications', level: 2 },
          { type: :text, libelle: 'Statut' },
        ],
        instructeurs: [instructeur])
    end
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    it 'numbers private sections hierarchically and independently', if: PDFTOTEXT_AVAILABLE do
      assign(:dossier, dossier)
      assign(:acls, PiecesJustificativesService.new(user_profile: instructeur, export_template: nil).acl_for_dossier_export(procedure))
      render template: 'dossiers/show', formats: [:pdf]

      pdf_path = Rails.root.join('tmp/test_show_private.pdf')
      File.binwrite(pdf_path, rendered)
      text = `pdftotext -layout #{pdf_path} - 2>/dev/null`

      expect(text).to include('1. Notes')
      expect(text).to include('1.1. Vérifications')
    end
  end

  describe 'no header sections' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :text, libelle: 'Nom complet' },
        { type: :text, libelle: 'Téléphone' },
      ])
    end
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    it 'renders without indentation regression', if: PDFTOTEXT_AVAILABLE do
      text = render_and_extract(dossier, procedure, 'no_headers')
      expect(text).to include('Nom complet')
      expect(text).to include('Téléphone')
    end
  end

  describe 'manually numbered libellés (opt-out)' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :header_section, libelle: '1 - Manuellement numéroté', level: 1 },
        { type: :header_section, libelle: '1.a Sous-section', level: 2 },
        { type: :text, libelle: 'Champ' },
      ])
    end
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    it 'preserves user libellés without auto prefix but still indents', if: PDFTOTEXT_AVAILABLE do
      text = render_and_extract(dossier, procedure, 'manual_num')
      expect(text).to include('1 - Manuellement numéroté')
      expect(text).to include('1.a Sous-section')
      expect(text).not_to match(/^\s*1\.\s+1 -/) # pas de "1. 1 -"
    end
  end

  describe 'invisible conditional sub-header' do
    include Logic
    let(:stable_id_number) { 99 }
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :header_section, libelle: 'Parent', level: 1 },
        { type: :integer_number, libelle: 'Critère', stable_id: stable_id_number },
        { type: :header_section, libelle: 'Caché', level: 2, condition: ds_eq(champ_value(stable_id_number), constant(5)) },
        { type: :text, libelle: 'Optionnel' },
        { type: :header_section, libelle: 'Visible', level: 2 },
        { type: :text, libelle: 'Toujours' },
      ])
    end
    let(:dossier) do
      d = create(:dossier, :en_construction, procedure: procedure)
      d.root_public_champs.find { _1.stable_id == stable_id_number }&.update(value: 1)
      d.reload
      d
    end

    it 'skips invisible header and numbers next visible as 1.1', if: PDFTOTEXT_AVAILABLE do
      text = render_and_extract(dossier, procedure, 'invisible')
      expect(text).to include('1. Parent')
      expect(text).not_to include('Caché')
      expect(text).to include('1.1. Visible')
    end
  end

  describe 'diverse champ types under indented headers' do
    let(:procedure) do
      create(:procedure, types_de_champ_public: [
        { type: :header_section, libelle: 'Coordonnées', level: 1 },
        { type: :header_section, libelle: 'Adresse', level: 2 },
        { type: :address, libelle: 'Adresse postale' },
        { type: :drop_down_list, libelle: 'Civilité', options: ['M.', 'Mme'] },
        { type: :textarea, libelle: 'Commentaire' },
      ])
    end
    let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

    it 'renders without error for varied types under indent' do
      expect { render_and_extract(dossier, procedure, 'varied_types') }.not_to raise_error
    end
  end

  describe 'france connect champ whose data is not rendered yet' do
    let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :aah, libelle: 'AAH' }]) }
    let(:dossier) do
      d = create(:dossier, :en_construction, procedure:)
      d.root_public_champs.first.update(external_state: 'fetched', value: 'true', value_json: { api_part: { est_beneficiaire: true } })
      d
    end

    it 'does not print the raw confirmation value', if: PDFTOTEXT_AVAILABLE do
      text = render_and_extract(dossier, procedure, 'aah')

      expect(text).not_to include('true')
    end
  end
end
