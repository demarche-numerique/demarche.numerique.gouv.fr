# frozen_string_literal: true

describe DossierRebaseConcern do
  describe '#can_rebase?' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ mandatory: true }, { type: :yes_no, mandatory: false }], private_type_de_champs: [{}]) }
    let(:attestation_template) { procedure.draft_revision.attestation_acceptation_template.find_or_revise! }
    let(:type_de_champ) { procedure.active_revision.public_root_type_de_champs.find { |tdc| !tdc.mandatory? } }
    let(:private_type_de_champ) { procedure.active_revision.private_root_type_de_champs.first }
    let(:mandatory_type_de_champ) { procedure.active_revision.public_root_type_de_champs.find(&:mandatory?) }

    context 'on unpublished procedure' do
      context 'en_construction' do
        let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

        it 'should be false' do
          expect(dossier.pending_changes).to be_empty
          expect(dossier.can_rebase?).to be_falsey
        end
      end
    end

    context 'en_construction' do
      let(:dossier) { create(:dossier, :en_construction, procedure: procedure) }

      before do
        procedure.publish!(procedure.administrateurs.first)
        procedure.reload
        dossier
      end

      context 'with added type de champ' do
        before do
          procedure.draft_revision.add_type_de_champ({
            type: TypesDeChamp::Text.name,
            libelle: "Un champ text",
          })
          procedure.publish_revision!(procedure.administrateurs.first)
          dossier.reload
        end

        it 'should be true' do
          expect(dossier.pending_changes).not_to be_empty
          expect(dossier.can_rebase?).to be_truthy
        end
      end
    end

    context 'en_instruction' do
      let(:dossier) { create(:dossier, :en_instruction, procedure: procedure) }

      before do
        procedure.publish!(procedure.administrateurs.first)
        procedure.reload
        dossier
      end

      context 'with added type de champ' do
        before do
          procedure.draft_revision.add_type_de_champ({
            type: TypesDeChamp::Text.name,
            libelle: "Un champ text",
          })
          procedure.publish_revision!(procedure.administrateurs.first)
          dossier.reload
        end

        it 'should be true' do
          expect(dossier.pending_changes).not_to be_empty
          expect(dossier.can_rebase?).to be_truthy
        end
      end
    end

    context 'accepte' do
      let(:dossier) { create(:dossier, :accepte, procedure: procedure) }

      before do
        procedure.publish!(procedure.administrateurs.first)
        procedure.reload
        dossier
      end

      context 'with added type de champ' do
        before do
          procedure.draft_revision.add_type_de_champ({
            type: TypesDeChamp::Text.name,
            libelle: "Un champ text",
          })
          procedure.publish_revision!(procedure.administrateurs.first)
          dossier.reload
        end

        it 'should be true' do
          expect(dossier.pending_changes).not_to be_empty
          expect(dossier.can_rebase?).to be_falsey
        end
      end
    end
  end

  describe "#rebase" do
    let(:procedure) { create(:procedure, public_type_de_champs:, private_type_de_champs:) }
    let(:public_type_de_champs) do
      [
        { type: :text, mandatory: true, stable_id: 1 },
        {
          type: :repetition, stable_id: 101, mandatory: true, children: [
            { type: :text, stable_id: 102 },
          ],
        },
        { type: :datetime, stable_id: 103 },
        { type: :yes_no, stable_id: 104 },
        { type: :integer_number, stable_id: 105 },
      ]
    end
    let(:private_type_de_champs) { [{ type: :text, stable_id: 11 }] }
    let(:dossier) { create(:dossier, :with_entreprise, procedure: procedure) }
    let(:type_de_champs) { procedure.active_revision.type_de_champs }

    let(:text_type_de_champ) { type_de_champs.find { _1.stable_id == 1 } }
    let(:repetition_type_de_champ) { type_de_champs.find { _1.stable_id == 101 } }
    let(:repetition_text_type_de_champ) { type_de_champs.find { _1.stable_id == 102 } }
    let(:datetime_type_de_champ) { type_de_champs.find { _1.stable_id == 103 } }
    let(:yes_no_type_de_champ) { type_de_champs.find { _1.stable_id == 104 } }

    let(:text_champ) { dossier.root_champs_public.find { _1.stable_id == 1 } }
    let(:repetition_champ) { dossier.root_champs_public.find { _1.stable_id == 101 } }
    let(:datetime_champ) { dossier.root_champs_public.find { _1.stable_id == 103 } }

    let(:rebased_text_champ) { dossier.root_champs_public.find { _1.stable_id == 1 } }
    let(:rebased_repetition_champ) { dossier.root_champs_public.find { _1.stable_id == 101 } }
    let(:rebased_datetime_champ) { dossier.root_champs_public.find { _1.stable_id == 103 } }
    let(:rebased_number_champ) { dossier.root_champs_public.find { _1.stable_id == 105 } }

    let(:rebased_new_repetition_champ) { dossier.root_champs_public.find { _1.libelle == "une autre repetition" } }

    let(:private_text_type_de_champ) { type_de_champs.find { _1.stable_id == 11 } }
    let(:rebased_private_text_champ) { dossier.root_champs_private.find { _1.stable_id == 11 } }

    context "when revision is published" do
      before do
        stub_request(:post, WEASYPRINT_URL).to_return(body: '%PDF-1.4 fake')
        procedure.publish!(procedure.administrateurs.first)
        procedure.draft_revision.add_type_de_champ({
          type: TypesDeChamp::Text.name,
          libelle: "Un champ text",
        })
        procedure.draft_revision.add_type_de_champ({
          type: TypesDeChamp::PieceJustificative.name,
          libelle: "Un champ pj",
        })
        procedure.draft_revision.find_and_ensure_exclusive_use(text_type_de_champ.stable_id).update(mandatory: false, libelle: "nouveau libelle")
        procedure.draft_revision.find_and_ensure_exclusive_use(datetime_type_de_champ.stable_id).becomes!(TypesDeChamp::Date).save
        procedure.draft_revision.find_and_ensure_exclusive_use(repetition_text_type_de_champ.stable_id).update(libelle: "nouveau libelle dans une repetition")
        procedure.draft_revision.add_type_de_champ({
          type: TypesDeChamp::Checkbox.name,
          libelle: "oui ou non",
          parent_stable_id: repetition_type_de_champ.stable_id,
        })
        procedure.draft_revision.remove_type_de_champ(yes_no_type_de_champ.stable_id)
        new_repetition_type_de_champ = procedure.draft_revision.add_type_de_champ({
          type: TypesDeChamp::Repetition.name,
          libelle: "une autre repetition",
          mandatory: true,
        })
        procedure.draft_revision.add_type_de_champ({
          type: TypesDeChamp::Text.name,
          libelle: "un champ text dans une autre repetition",
          parent_stable_id: new_repetition_type_de_champ.stable_id,
        })
        procedure.draft_revision.add_type_de_champ({
          type: TypesDeChamp::Date.name,
          libelle: "un champ date dans une autre repetition",
          parent_stable_id: new_repetition_type_de_champ.stable_id,
        })

        datetime_champ.update(value: Time.zone.now.to_s)
        text_champ.update(value: 'bonjour')
        text_champ.type_de_champ
        # Add two rows then remove previous to last row in order to create a "hole" in the sequence
        repetition_champ.add_row(updated_by: 'test')
        repetition_champ.add_row(updated_by: 'test')
        repetition_champ.dossier.champ_data.where(row_id: repetition_champ.row_ids[-2]).destroy_all
        dossier.reload
      end

      it "updates the brouillon champs with the latest revision changes", :slow do
        expect(dossier.revision).to eq(procedure.published_revision)
        expect(dossier.root_champs_public.size).to eq(5)
        expect(dossier.champ_data.count(&:public?)).to eq(6)
        expect(repetition_champ.rows.size).to eq(2)
        expect(repetition_champ.rows[0].size).to eq(1)
        expect(repetition_champ.rows[1].size).to eq(1)

        procedure.publish_revision!(procedure.administrateurs.first)
        perform_enqueued_jobs
        procedure.reload
        dossier.reload

        expect(procedure.revisions.size).to eq(3)
        expect(dossier.revision).to eq(procedure.published_revision)
        expect(dossier.root_champs_public.size).to eq(7)
        expect(dossier.champ_data.count(&:public?)).to eq(7)
        expect(rebased_text_champ.value).to eq(text_champ.value)
        expect(rebased_text_champ.type_de_champ).not_to eq(text_champ.type_de_champ)
        expect(rebased_datetime_champ.type_champ).to eq(TypeDeChamp.type_champs.fetch(:date))
        expect(rebased_datetime_champ.value).to be_nil
        expect(rebased_repetition_champ.rows.size).to eq(2)
        expect(rebased_repetition_champ.rows[0].size).to eq(2)
        expect(rebased_repetition_champ.rows[1].size).to eq(2)
        expect(rebased_text_champ.rebased_at).not_to be_nil
        expect(rebased_datetime_champ.rebased_at).not_to be_nil
        expect(rebased_number_champ.rebased_at).to be_nil
        expect(rebased_new_repetition_champ).not_to be_nil
        expect(rebased_new_repetition_champ.rows.size).to eq(1)
        expect(rebased_new_repetition_champ.rows[0].size).to eq(2)

        dossier.passer_en_construction!
        procedure.draft_revision.find_and_ensure_exclusive_use(private_text_type_de_champ.stable_id).becomes!(TypesDeChamp::Textarea).save
        procedure.publish_revision!(procedure.administrateurs.first)
        perform_enqueued_jobs
        procedure.reload
        dossier.reload

        expect(rebased_private_text_champ.type_champ).to eq(TypeDeChamp.type_champs.fetch(:textarea))
        expect(rebased_private_text_champ.type).to eq("Champs::TextareaChamp")
      end
    end

    context 'rebase en construction' do
      subject { dossier.rebase! }

      context 'procedure not published' do
        let(:procedure) { create(:procedure, :draft, public_type_de_champs:, private_type_de_champs:) }
        let(:dossier) { create(:dossier, :en_construction, procedure:) }

        it 'is noop' do
          expect { subject }.not_to change { dossier.reload.root_champs_public[0].rebased_at }
          expect { subject }.not_to change { dossier.updated_at }
        end
      end
    end
  end

  context 'small grained' do
    subject do
      procedure.publish_revision!(procedure.administrateurs.first)
      perform_enqueued_jobs

      dossier.reload
    end

    context 'with a procedure with a dropdown tdc' do
      let!(:procedure) do
        create(:procedure).tap do |p|
          p.draft_revision.add_type_de_champ(type: TypesDeChamp::DropDownList.name, libelle: 'l1', drop_down_options: ["option", "v1"])
          p.publish!(p.administrateurs.first)
        end
      end
      let!(:dossier) { create(:dossier, procedure: procedure) }

      context 'when a dropdown option is added' do
        before do
          dossier.root_champs_public.first.update(value: 'v1')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["option", "updated", "v1"])
        end

        it { expect { subject }.not_to change { dossier.root_champs_public.first.to_s } }
      end

      context 'when a dropdown option is removed' do
        before do
          dossier.root_champs_public.first.update(value: 'v1')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["option", "updated"])
        end

        it { expect { subject }.not_to change { dossier.root_champs_public.first.to_s } }
      end

      context 'when a dropdown unused option is removed' do
        before do
          dossier.root_champs_public.first.update(value: 'v1')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["v1", "updated"])
        end

        it { expect { subject }.not_to change { dossier.root_champs_public.first.to_s } }
      end
    end

    context 'with a procedure with a multiple dropdown tdc' do
      let!(:procedure) do
        create(:procedure).tap do |p|
          p.draft_revision.add_type_de_champ(type: TypesDeChamp::MultipleDropDownList.name, libelle: 'l1', drop_down_options: ["option", "v1"])
          p.publish!(p.administrateurs.first)
        end
      end
      let!(:dossier) { create(:dossier, procedure: procedure) }

      context 'when a dropdown option is added' do
        before do
          dossier.root_champs_public.first.update(value: '["v1"]')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["option", "updated", "v1"])
        end

        it { expect { subject }.not_to change { dossier.root_champs_public.first.to_s } }
      end

      context 'when a dropdown option is removed' do
        before do
          dossier.root_champs_public.first.update(value: '["v1", "option"]')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["option", "updated"])
        end

        it { expect { subject }.not_to change { dossier.root_champs_public.first.to_s } }
      end

      context 'when a dropdown unused option is removed' do
        before do
          dossier.root_champs_public.first.update(value: '["v1"]')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["v1", "updated"])
        end

        it { expect { subject }.not_to change { dossier.root_champs_public.first.to_s } }
      end
    end

    context 'with a procedure with a linked dropdown tdc' do
      let!(:procedure) do
        create(:procedure).tap do |p|
          p.draft_revision.add_type_de_champ(type: TypesDeChamp::LinkedDropDownList.name, libelle: 'l1', drop_down_options: ["--titre1--", "option", "v1", "--titre2--", "option2", "v2"])
          p.publish!(p.administrateurs.first)
        end
      end
      let!(:dossier) { create(:dossier, procedure: procedure) }

      context 'when a dropdown option is added' do
        before do
          dossier.root_champs_public.first.update(value: '["titre1",""]')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["--titre1--", "option", "v1", "updated", "--titre2--", "option2", "v2"])
        end

        it { expect { subject }.not_to change { dossier.root_champs_public.first.to_s } }
      end

      context 'when a dropdown option is removed' do
        before do
          dossier.root_champs_public.first.update(value: '["titre2","option2"]')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["--titre1--", "option", "updated", "--titre2--", "v2"])
        end

        it { expect { subject }.to change { dossier.root_champs_public.first.to_s }.from('titre2 / option2').to('titre2') }
      end

      context 'when a dropdown unused option is removed' do
        before do
          dossier.root_champs_public.first.update(value: '["titre2",""]')

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(drop_down_options: ["--titre1--", "v1", "updated", "--titre2--", "option2", "v2"])
        end

        it { expect { subject }.not_to change { dossier.root_champs_public.first.to_s } }
      end
    end

    context 'with a procedure with a carte tdc' do
      let!(:procedure) do
        create(:procedure).tap do |p|
          champ = p.draft_revision.add_type_de_champ(type: TypesDeChamp::Carte.name, libelle: 'l1', cadastres: true)
          p.publish!(p.administrateurs.first)
        end
      end
      let!(:dossier) { create(:dossier, procedure: procedure) }

      context 'and the cadastre are removed' do
        before do
          dossier.root_champs_public.first.update(value: 'v1', geo_areas: [build(:geo_area, :cadastre)])

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(cadastres: false)
        end

        it { expect { subject }.to change { dossier.root_champs_public.first.cadastres.count }.from(1).to(0) }
      end
    end

    context 'with a procedure with 2 tdc' do
      let!(:procedure) do
        create(:procedure, :published, public_type_de_champs: [{ type: :text, libelle: 'l1' }, { type: :text, libelle: 'l2' }])
      end
      let!(:dossier) { create(:dossier, procedure: procedure) }

      def champ_libelles = dossier.revision.public_root_type_de_champs.map(&:libelle)

      context 'when a tdc is added in the middle' do
        before do
          added_tdc = procedure.draft_revision.add_type_de_champ(type: TypesDeChamp::Text.name, libelle: 'l3')
          procedure.draft_revision.move_type_de_champ(added_tdc.stable_id, 1)
        end

        it { expect { subject }.to change { champ_libelles }.from(['l1', 'l2']).to(['l1', 'l3', 'l2']) }
      end

      context 'when the first tdc is removed' do
        before do
          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_remove = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          procedure.draft_revision.remove_type_de_champ(tdc_to_remove.stable_id)
        end

        it { expect { subject }.to change { champ_libelles }.from(['l1', 'l2']).to(['l2']) }
      end

      context 'when the second tdc is moved at the first place' do
        before do
          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l2' }
          procedure.draft_revision.move_type_de_champ(stable_id, 0)
        end

        it { expect { subject }.to change { champ_libelles }.from(['l1', 'l2']).to(['l2', 'l1']) }
      end

      context 'when the first tdc libelle is updated' do
        before do
          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(libelle: 'l1 updated')
        end

        it { expect { subject }.to change { champ_libelles }.from(['l1', 'l2']).to(['l1 updated', 'l2']) }
      end

      context 'when the first tdc type is updated' do
        def first_champ = dossier.root_champs_public.first

        before do
          first_champ.update(value: 'v1', external_id: '123', geo_areas: [build(:geo_area)])
          first_champ.update(data: { a: 1 })

          first_champ.piece_justificative_file.attach(
            io: StringIO.new("toto"),
            filename: "toto.txt",
            content_type: "text/plain",
            # we don't want to run virus scanner on this file
            metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
          )

          first_champ.update_column('updated_at', Time.zone.parse('01/01/1901'))

          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'l1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.becomes!(TypesDeChamp::IntegerNumber).save
        end

        it { expect { subject }.to change { dossier.revision.public_root_type_de_champs.map(&:type_champ) }.from(['text', 'text']).to(['integer_number', 'text']) }
        it { expect { subject }.to change { first_champ.class }.from(Champs::TextChamp).to(Champs::IntegerNumberChamp) }
        it { expect { subject }.not_to change { first_champ.to_s } }
        it { expect { subject }.to change { first_champ.external_id }.from('123').to(nil) }
        it { expect { subject }.to change { first_champ.data }.from({ 'a' => 1 }).to(nil) }
        it { expect { subject }.to change { first_champ.geo_areas.count }.from(1).to(0) }
        it { expect { subject }.to change { first_champ.piece_justificative_file.attached? }.from(true).to(false) }
        it { expect { subject }.not_to change { first_champ.updated_at }.from(Time.zone.parse('01/01/1901')) }
      end
    end

    context 'with a procedure with a repetition' do
      let!(:procedure) do
        create(:procedure, :published, public_type_de_champs: [
          {
            type: :repetition,
            libelle: 'p1',
            mandatory: true,
            children: [
              { type: :text, libelle: 'c1' },
              { type: :text, libelle: 'c2' },
            ],
          },
        ])
      end
      let!(:dossier) { create(:dossier, procedure: procedure) }
      let(:repetition) { procedure.draft_revision.type_de_champs.find(&:repetition?) }

      def child_libelles = dossier.revision.public_revision_type_de_champs.first.revision_type_de_champs.map(&:libelle)
      def child_types_champ = dossier.revision.public_revision_type_de_champs.first.revision_type_de_champs.map(&:type_champ)

      context 'when a child tdc is added in the middle' do
        before do
          last_child = procedure.draft_revision.children_of(repetition).last
          added_tdc = procedure.draft_revision.add_type_de_champ(type: TypesDeChamp::Text.name, libelle: 'c3', parent_stable_id: repetition.stable_id, after_stable_id: last_child)
          procedure.draft_revision.move_type_de_champ(added_tdc.stable_id, 1)
          # procedure.publish_revision!(procedure.administrateurs.first)
        end

        it 'does somehting' do
          expect { subject }.to change { child_libelles }.from(['c1', 'c2']).to(['c1', 'c3', 'c2'])
        end
      end

      context 'when the first child tdc is removed' do
        before do
          tdc_to_remove = procedure.draft_revision.type_de_champs.find { _1.libelle == 'c1' }
          procedure.draft_revision.remove_type_de_champ(tdc_to_remove.stable_id)
        end

        it { expect { subject }.to change { child_libelles }.from(['c1', 'c2']).to(['c2']) }
      end

      context 'when the first child libelle tdc is updated' do
        before do
          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'c1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.update(libelle: 'c1 updated')
        end

        it { expect { subject }.to change { child_libelles }.from(['c1', 'c2']).to(['c1 updated', 'c2']) }
      end

      context 'when the first child tdc type is updated' do
        before do
          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'c1' }
          tdc_to_update = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          tdc_to_update.becomes!(TypesDeChamp::IntegerNumber).save
        end

        it { expect { subject }.to change { child_types_champ }.from(['text', 'text']).to(['integer_number', 'text']) }
      end

      context 'when the parents type is changed' do
        before do
          stable_id = procedure.draft_revision.type_de_champs.find { _1.libelle == 'p1' }
          parent = procedure.draft_revision.find_and_ensure_exclusive_use(stable_id)
          parent.becomes!(TypesDeChamp::IntegerNumber).save
        end

        it { expect { subject }.to change { dossier.root_champs_public.find(&:repetition?)&.libelle }.from('p1').to(nil) }
        it { expect { subject }.not_to change { ChampData.count } }
      end
    end
  end
end
