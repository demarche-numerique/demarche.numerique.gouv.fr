# frozen_string_literal: true

describe InstructeurExportBannerConcern do
  let(:procedure) { procedures.individual }
  let(:gi) { procedure.defaut_groupe_instructeur }
  let(:instructeur) { instructeurs.default }
  let(:colleague) { create(:instructeur, groupe_instructeurs: [gi]) }

  before { instructeur.update!(export_banner_dismissed_at: nil) }

  def ready(export)
    export.file.attach(io: StringIO.new('x'), filename: 'e.csv')
    export.update!(job_status: :generated)
    export
  end

  describe '#export_for_banner' do
    it 'returns nil without any export' do
      expect(instructeur.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'starts with exports completed before account creation dismissed' do
      travel_to(1.hour.ago) { ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague)) }
      newcomer = create(:instructeur, groupe_instructeurs: [gi])

      expect(newcomer.reload.export_banner_dismissed_at).to be_present
      expect(newcomer.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'returns an own pending or failed export' do
      export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!
      expect(instructeur.export_for_banner(pro_connect: false)).to eq(export)
      export.update!(job_status: :failed)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(export)
    end

    it 'hides an own export dismissed before it was ready, until it gets ready' do
      export = travel_to(2.minutes.ago) { create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur) }
      instructeur.request_export!
      travel_to(1.minute.ago) { instructeur.dismiss_export_banner! }
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
      export.update!(job_status: :failed)
      export.update!(job_status: :pending)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
      ready(export)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(export)
    end

    it 'hides an own export dismissed once ready' do
      ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur))
      instructeur.request_export!
      instructeur.dismiss_export_banner!
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'keeps earlier colleague exports hidden after closing the own pending export' do
      travel_to(2.minutes.ago) { ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague)) }
      create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!

      instructeur.dismiss_export_banner!

      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'keeps earlier own exports hidden after closing a colleague export' do
      travel_to(2.minutes.ago) { ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur)) }
      instructeur.request_export!
      ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))

      instructeur.dismiss_export_banner!

      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'shows an own failure after its pending banner was closed' do
      own = travel_to(2.minutes.ago) { create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur) }
      instructeur.request_export!
      travel_to(1.minute.ago) { instructeur.dismiss_export_banner! }

      own.update!(job_status: :failed)

      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(own)
    end

    it 'shows a newer ready colleague export instead of an older own failure' do
      travel_to(2.minutes.ago) { create(:export, :failed, groupe_instructeurs: [gi], user_profile: instructeur) }
      instructeur.request_export!
      latest = ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))

      expect(instructeur.export_for_banner(pro_connect: false)).to eq(latest)
    end

    it 'shows a dismissed own export again when it is requested again' do
      export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!
      instructeur.dismiss_export_banner!
      instructeur.request_export!
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(export)
    end

    it 'returns nil once the own export is purged' do
      export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!
      export.destroy!
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'returns nil when the instructeur left a group of the export' do
      create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!
      instructeur.assign_to.find_by(groupe_instructeur: gi).destroy!
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'returns nil when the own export also covers a group the instructeur is not in' do
      other_gi = create(:groupe_instructeur, procedure:, instructeurs: [colleague])
      create(:export, :pending, groupe_instructeurs: [gi, other_gi], user_profile: instructeur)
      instructeur.request_export!
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'returns the most recently ready colleague export' do
      travel_to(2.minutes.ago) { ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague)) }
      latest = ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
      expect(instructeur.export_for_banner(pro_connect: false)).to eq(latest)
    end

    it 'ignores pending and failed colleague exports' do
      create(:export, :pending, groupe_instructeurs: [gi], user_profile: colleague)
      create(:export, :failed, groupe_instructeurs: [gi], user_profile: colleague)
      expect(instructeur.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'ignores a colleague export covering a group the instructeur is not in' do
      other_gi = create(:groupe_instructeur, procedure:, instructeurs: [colleague])
      ready(create(:export, groupe_instructeurs: [gi, other_gi], user_profile: colleague))
      expect(instructeur.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'ignores colleague exports for a super admin assigned as manager' do
      instructeur.assign_to.find_by(groupe_instructeur: gi).update!(manager: true)
      ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
      expect(instructeur.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'ignores exports requested by an administrateur' do
      ready(create(:export, groupe_instructeurs: [gi], user_profile: create(:administrateur)))
      expect(instructeur.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'prefers the own export over a newer colleague export' do
      own = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!
      ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
      expect(instructeur.export_for_banner(pro_connect: false)).to eq(own)
    end

    it 'shows the latest completed event even when an earlier own export exists' do
      travel_to(2.minutes.ago) { ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur)) }
      latest = ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))

      expect(instructeur.export_for_banner(pro_connect: false)).to eq(latest)
    end

    it 'shows an own failure more recent than a ready colleague export' do
      travel_to(2.minutes.ago) { ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague)) }
      latest = create(:export, :failed, groupe_instructeurs: [gi], user_profile: instructeur)

      expect(instructeur.export_for_banner(pro_connect: false)).to eq(latest)
    end

    it 'shows a dismissed ready export again without refreshing its file age' do
      export = ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur))
      instructeur.dismiss_export_banner!

      expect { instructeur.request_export! }.not_to change { export.reload.updated_at }
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(export)
    end

    it 'does not let a generated export without a file hide an older ready export' do
      ready_export = travel_to(2.minutes.ago) { ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague)) }
      create(:export, :generated, groupe_instructeurs: [gi], user_profile: colleague)

      expect(instructeur.export_for_banner(pro_connect: false)).to eq(ready_export)
    end

    it 'ignores a generated colleague export whose file is not attached' do
      create(:export, :generated, groupe_instructeurs: [gi], user_profile: colleague)
      expect(instructeur.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'hides colleague exports ready before the last dismissal' do
      ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
      instructeur.dismiss_export_banner!
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
      newer = travel_to(1.minute.from_now) { ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague)) }
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(newer)
    end

    context 'when the procedure is deleted' do
      before { procedure.discard! }

      [true, false].each do |pro_connect|
        context "with pro_connect: #{pro_connect}" do
          it 'hides an own export' do
            ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur))
            instructeur.request_export!
            expect(instructeur.reload.export_for_banner(pro_connect:)).to be_nil
          end

          it 'hides a colleague export' do
            ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
            expect(instructeur.export_for_banner(pro_connect:)).to be_nil
          end
        end
      end
    end

    context 'when the procedure is restricted to ProConnect' do
      before { procedure.update!(pro_connect_restriction: :instructeurs) }

      it 'hides an own export without a ProConnect session' do
        export = ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur))
        instructeur.request_export!
        expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
        expect(instructeur.export_for_banner(pro_connect: true)).to eq(export)
      end

      it 'hides a colleague export without a ProConnect session' do
        export = ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
        expect(instructeur.export_for_banner(pro_connect: false)).to be_nil
        expect(instructeur.export_for_banner(pro_connect: true)).to eq(export)
      end
    end
  end
end
