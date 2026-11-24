# frozen_string_literal: true

describe TypesDeChamp::DossierLinkTypeDeChamp, 'linked dossier snapshot columns' do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :dossier_link }]) }
  let(:tdc) { procedure.active_revision.public_root_type_de_champs.first }
  let(:columns) { tdc.columns(procedure_id: procedure.id) }
  let(:date_column) { columns.second }
  let(:title_column) { columns.third }
  let(:agency_column) { columns.fourth }

  def dossier_with_snapshot(snapshot, state: :en_construction, on: procedure, stream: Dossier::MAIN_STREAM, **attributes)
    create(:dossier, state, procedure: on, **attributes).tap do |dossier|
      dossier.champ_data.update_all(value_json: snapshot, stable_id: tdc.stable_id, stream:)
      (@snapshot_dossier_ids ||= []) << dossier.id
    end
  end

  it 'displays saved values after the linked procedure has been deleted' do
    target = create(:procedure, libelle: 'Écoles', organisation: 'Service scolaire')
    dossier = dossier_with_snapshot({ procedure_title: target.libelle, procedure_agency: target.organisation, submitted_on: '2026-03-04' })
    target.destroy!
    champ = dossier.champ_data.first

    expect(title_column.value(champ)).to eq('Écoles')
    expect(agency_column.value(champ)).to eq('Service scolaire')
    expect(date_column.value(champ)).to eq(Date.new(2026, 3, 4))
    expect(count_queries(matching: /"champs"|"procedures"/) { expect(title_column.label_for_value('Écoles')).to eq('Écoles') }).to eq(0)
    expect(title_column.label_for_value('nil')).to eq('nil')
  end

  it 'lists distinct non-blank titles from submitted dossiers of this procedure and main stream' do
    dossier_with_snapshot({ procedure_title: 'Écoles' })
    dossier_with_snapshot({ procedure_title: 'Écoles' }, state: :accepte)
    dossier_with_snapshot({ procedure_title: 'ateliers' })
    dossier_with_snapshot({ procedure_title: 'Zones' })
    dossier_with_snapshot({ procedure_title: ' ' })
    dossier_with_snapshot({ procedure_title: 'Brouillon' }, state: :brouillon)
    dossier_with_snapshot({ procedure_title: 'Prévisualisation' }, for_procedure_preview: true)
    dossier_with_snapshot({ procedure_title: 'Copie' }, stream: Dossier::USER_BUFFER_STREAM)
    other_procedure = create(:procedure, public_type_de_champs: [{ type: :dossier_link }])
    dossier_with_snapshot({ procedure_title: 'Autre démarche' }, on: other_procedure)

    expect(title_column.options_for_dossiers(Dossier.where(id: @snapshot_dossier_ids))).to eq([['ateliers', 'ateliers'], ['Écoles', 'Écoles'], ['Zones', 'Zones']])
  end

  it 'filters by exact stored title, including apostrophes' do
    first = dossier_with_snapshot({ procedure_title: "Aide à l'école" })
    second = dossier_with_snapshot({ procedure_title: "Aide à l'école primaire" })
    dossiers = Dossier.where(id: [first, second])

    expect(title_column.filtered_ids(dossiers, { operator: 'match', value: ["Aide à l'école"] })).to eq([first.id])
    expect(title_column.filtered_ids(dossiers, { operator: 'match', value: ["Aide à l'école", "Aide à l'école primaire"] })).to contain_exactly(first.id, second.id)
  end

  it 'sorts the columns by saved date, title or service' do
    first = dossier_with_snapshot({ procedure_title: 'Aide', procedure_agency: 'Culture', submitted_on: '2026-05-06' })
    second = dossier_with_snapshot({ procedure_title: 'Bourse', procedure_agency: 'Animation', submitted_on: '2026-03-04' })
    third = dossier_with_snapshot({ procedure_title: 'Carte', procedure_agency: 'Bibliothèque', submitted_on: '2026-04-05' })
    fourth = dossier_with_snapshot({ procedure_title: 'Aide', procedure_agency: 'Culture', submitted_on: '2026-05-06' })
    blank = dossier_with_snapshot({})
    dossiers = Dossier.where(id: [first, second, third, fourth, blank])

    expect(date_column.sorted_ids(dossiers, 'asc', count: 5)).to eq([second.id, third.id, first.id, fourth.id, blank.id])
    expect(title_column.sorted_ids(dossiers, 'asc', count: 5)).to eq([first.id, fourth.id, second.id, third.id, blank.id])
    expect(agency_column.sorted_ids(dossiers, 'desc', count: 5)).to eq([blank.id, fourth.id, first.id, third.id, second.id])
  end
end
