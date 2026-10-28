# frozen_string_literal: true

describe InstructeurExportBannerConcern do
  let(:procedure) { create(:procedure) }
  let(:gi) { procedure.defaut_groupe_instructeur }
  let(:instructeur) { create(:instructeur, groupe_instructeurs: [gi]) }
  let(:colleague) { create(:instructeur, groupe_instructeurs: [gi]) }

  def ready(export)
    export.file.attach(io: StringIO.new('x'), filename: 'e.csv')
    export.update!(job_status: :generated)
    export
  end

  describe '#export_for_banner' do
    it 'returns nil without any export' do
      expect(instructeur.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'returns the last requested export whatever its state' do
      export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!(export)
      expect(instructeur.export_for_banner(pro_connect: false)).to eq(export)
      export.update!(job_status: :failed)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(export)
    end

    it 'hides an own export dismissed before it was ready, until it gets ready' do
      export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!(export)
      travel_to(1.minute.ago) { instructeur.dismiss_export_banner!(export.id) }
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
      export.update!(job_status: :failed)
      export.update!(job_status: :pending)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
      ready(export)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(export)
    end

    it 'hides an own export dismissed once ready' do
      export = ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur))
      instructeur.request_export!(export)
      instructeur.dismiss_export_banner!(export.id)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'shows a dismissed own export again when it is requested again' do
      export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!(export)
      instructeur.dismiss_export_banner!(export.id)
      instructeur.request_export!(export)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(export)
    end

    it 'returns nil once the own export is purged' do
      export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!(export)
      export.destroy!
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
    end

    it 'returns nil when the instructeur left a group of the export' do
      export = create(:export, :pending, groupe_instructeurs: [gi], user_profile: instructeur)
      instructeur.request_export!(export)
      instructeur.assign_to.find_by(groupe_instructeur: gi).destroy!
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
      instructeur.request_export!(own)
      ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
      expect(instructeur.export_for_banner(pro_connect: false)).to eq(own)
    end

    it 'hides colleague exports ready before the last dismissal' do
      old = ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague))
      instructeur.dismiss_export_banner!(old.id)
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to be_nil
      newer = travel_to(1.minute.from_now) { ready(create(:export, groupe_instructeurs: [gi], user_profile: colleague)) }
      expect(instructeur.reload.export_for_banner(pro_connect: false)).to eq(newer)
    end

    context 'when the procedure is restricted to ProConnect' do
      before { procedure.update!(pro_connect_restriction: :instructeurs) }

      it 'hides an own export without a ProConnect session' do
        export = ready(create(:export, groupe_instructeurs: [gi], user_profile: instructeur))
        instructeur.request_export!(export)
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
