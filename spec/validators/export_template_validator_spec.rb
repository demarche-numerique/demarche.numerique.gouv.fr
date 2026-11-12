# frozen_string_literal: true

describe ExportTemplateValidator do
  let(:validator) { ExportTemplateValidator.new }
  # the pieces jointes are read from the laid-out revision, which must be saved
  let(:groupe_instructeur) { procedures.brouillon.defaut_groupe_instructeur }

  describe 'validate' do
    let(:exportables_pieces_jointes) { [double('pj', stable_id: 3, libelle: 'libelle')] }
    let(:pj_libelle_by_stable_id) { exportables_pieces_jointes.map { |pj| [pj.stable_id, pj.libelle] }.to_h }

    def empty_template(enabled: true, stable_id: nil)
      { template: { type: "doc", content: [] }, enabled: enabled, stable_id: stable_id }.compact
    end

    def errors(export_template) = export_template.errors.map { [_1.attribute, _1.message] }

    before do
      allow(validator).to receive(:pj_libelle_by_stable_id).and_return(pj_libelle_by_stable_id)
      validator.validate(export_template)
    end

    context 'with a default export template' do
      let(:export_template) { build(:export_template, groupe_instructeur:) }

      it { expect(export_template.errors.count).to eq(0) }
    end

    context 'with a invalid template' do
      let(:export_template) do
        export_pdf = { template: { is: 'invalid' }, enabled: true }
        build(:export_template, groupe_instructeur:, export_pdf:)
      end

      it { expect(errors(export_template)).to eq([[:base, "Un nom de fichier est invalide"]]) }
    end

    context 'with a empty export_pdf' do
      let(:export_template) { build(:export_template, groupe_instructeur:, export_pdf: empty_template) }

      it { expect(errors(export_template)).to eq([[:export_pdf, "doit être rempli"]]) }
    end

    context 'with a empty export_pdf disabled' do
      let(:export_template) { build(:export_template, groupe_instructeur:, export_pdf: empty_template(enabled: false)) }

      it { expect(export_template.errors.count).to eq(0) }
    end

    context 'with a dossier_folder without dossier_number' do
      let(:export_template) do
        dossier_folder = ExportItem.default(prefix: 'dossier')
        dossier_folder.template[:content][0][:content][1][:attrs][:id] = :other

        build(:export_template, groupe_instructeur:, dossier_folder:)
      end

      it { expect(errors(export_template)).to eq([[:dossier_folder, "doit contenir le numéro du dossier"]]) }
    end

    context 'with a empty pj' do
      let(:export_template) { build(:export_template, groupe_instructeur:, pjs: [empty_template(stable_id: 3)]) }

      it { expect(errors(export_template)).to eq([[:libelle, "doit être rempli"]]) }
    end

    context 'with a empty pj disabled' do
      let(:export_template) { build(:export_template, groupe_instructeur:, pjs: [empty_template(enabled: false)]) }

      it { expect(export_template.errors.count).to eq(0) }
    end

    context 'with multiple files bearing the same template' do
      let(:export_item) { ExportItem.default(prefix: 'same') }

      let(:export_template) do
        build(:export_template, groupe_instructeur:, export_pdf: export_item, pjs: [export_item])
      end

      it { expect(errors(export_template)).to eq([[:base, "Les fichiers doivent avoir des noms différents"]]) }
    end

    context 'with multiple pjs using the original filename tag' do
      def original_filename_template(stable_id:)
        {
          template: {
            type: "doc",
            content: [
              {
                type: "paragraph",
                content: [{ type: "mention", attrs: { id: 'original-filename', label: 'nom original du fichier' } }],
              },
            ],
          },
          enabled: true,
          stable_id:,
        }
      end

      let(:export_template) do
        build(:export_template, groupe_instructeur:, pjs: [original_filename_template(stable_id: 3), original_filename_template(stable_id: 4)])
      end

      it { expect(export_template.errors.count).to eq(0) }
    end
  end
end
