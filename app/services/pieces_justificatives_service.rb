# frozen_string_literal: true

class PiecesJustificativesService
  def initialize(user_profile:, export_template:)
    @user_profile = user_profile
    @export_template = export_template
  end

  def liste_documents(dossiers)
    docs = pjs_for_champs(dossiers) +
      pjs_for_commentaires(dossiers) +
      pjs_for_dossier(dossiers) +
      pjs_for_avis(dossiers)

    # we do not export bills no more with the new export system
    # the bills have never been properly understood by the users
    # their export is now deprecated
    if liste_documents_allows?(:with_bills) && @export_template.nil?
      # some bills are shared among operations
      # so first, all the bill_ids are fetched
      operation_logs, some_bill_ids = operation_logs_and_signature_ids(dossiers)

      docs += operation_logs

      # then the bills are retrieved without duplication
      docs += signatures(some_bill_ids.uniq)
    end

    docs.filter { |_attachment, path| path.present? } # rubocop:disable Rails/CompactBlank
  end

  def generate_dossiers_export(dossiers) # TODO: renommer generate_dossier_export sans s
    return [] if dossiers.empty?
    return [] if @export_template && !@export_template.export_pdf.enabled?

    pdfs = []

    procedure = dossiers.first.procedure
    dossiers.each do |dossier|
      dossier.association(:procedure).target = procedure

      pdf = ApplicationController
        .render(template: 'dossiers/show', formats: [:pdf],
                assigns: {
                  acls: acl_for_dossier_export(procedure),
                  dossier: dossier,
                })
      a = ActiveStorage::FakeAttachment.new(
        file: StringIO.new(pdf),
        filename: ActiveStorage::Filename.new("export-#{dossier.id}.pdf"),
        name: 'pdf_export_for_instructeur',
        id: dossier.id,
        created_at: dossier.updated_at
      )

      if @export_template
        pdfs << [a, @export_template.attachment_path(dossier, a)]
      else
        pdfs << ActiveStorage::DownloadableFile.pj_and_path(dossier.id, a)
      end
    end

    pdfs
  end

  def self.serialize_types_de_champ_as_type_pj(revision)
    tdcs = revision.types_de_champ_public.filter { |type_champ| type_champ.old_pj.present? }
    tdcs.map.with_index do |type_champ, order_place|
      description = type_champ.description
      if /^(?<original_description>.*?)(?:[\r\n]+)Récupérer le formulaire vierge pour mon dossier : (?<lien_demarche>http.*)$/m =~ description
        description = original_description
      end
      {
        id: type_champ.old_pj[:stable_id],
        libelle: type_champ.libelle,
        description: description,
        order_place: order_place,
        lien_demarche: lien_demarche,
      }
    end
  end

  def acl_for_dossier_export(procedure)
    case @user_profile
    when Expert
      {
        include_messagerie: procedure.allow_expert_messaging,
        include_infos_administration: false,
        include_avis_for_expert: true,
        only_for_expert: @user_profile,
      }
    when Instructeur, Administrateur
      {
        include_messagerie: true,
        include_infos_administration: true,
        include_avis_for_expert: true,
        only_for_export: false,
      }
    when User
      {
        include_messagerie: true,
        include_infos_administration: false,
        include_avis_for_expert: false, # should be true, expert can use the messagerie, why not provide avis ?
        only_for_expert: false,
      }
    else
      raise 'not supported'
    end
  end

  private

  def liste_documents_allows?(scope)
    case @user_profile
    when Expert
      {
        with_bills: false,
        with_champs_private: false,
        with_avis_piece_justificative: false,
      }
    when Instructeur
      {
        with_bills: export_with_horodatage?,
        with_champs_private: true,
        with_avis_piece_justificative: true,
      }
    when Administrateur
      {
        with_bills: true,
        with_champs_private: true,
        with_avis_piece_justificative: true,
      }
    else
      raise 'not supported'
    end.fetch(scope)
  end

  def pjs_for_champs(dossiers)
    champs = liste_documents_allows?(:with_champs_private) ? dossiers.flat_map(&:filled_champs) : dossiers.flat_map(&:filled_champs_public)
    champs = champs.filter { it.piece_justificative? && it.is_type?(it.type_de_champ.type_champ) && !it.titre_identite? }

    champs_id_row_index = compute_champ_id_row_index(champs)

    champs.flat_map do |champ|
      champ.piece_justificative_file_attachments.filter { |a| safe_attachment(a) }.map.with_index do |attachment, index|
        row_index = champs_id_row_index[champ.id]

        if @export_template
          [attachment, @export_template.attachment_path(champ.dossier, attachment, index:, row_index:, champ:)]
        else
          ActiveStorage::DownloadableFile.pj_and_path(champ.dossier_id, attachment)
        end
      end
    end
  end

  def pjs_for_commentaires(dossiers)
    commentaire_id_dossier_id = Commentaire
      .joins(:piece_jointe_attachments)
      .where(dossier: dossiers)
      .pluck(:id, :dossier_id)
      .to_h

    ActiveStorage::Attachment
      .includes(:blob)
      .where(record_type: "Commentaire", record_id: commentaire_id_dossier_id.keys)
      .filter { |a| safe_attachment(a) }
      .map do |a|
        dossier_id = commentaire_id_dossier_id[a.record_id]
        if @export_template
          dossier = dossiers.find { _1.id == dossier_id }
          [a, @export_template.attachment_path(dossier, a)]
        else
          ActiveStorage::DownloadableFile.pj_and_path(dossier_id, a)
        end
      end
  end

  def pjs_for_dossier(dossiers)
    motivations(dossiers) +
      attestations(dossiers) +
      etablissements(dossiers)
  end

  def etablissements(dossiers)
    etablissement_id_dossier_id = Etablissement
      .where(dossier: dossiers)
      .pluck(:id, :dossier_id)
      .to_h

    ActiveStorage::Attachment
      .includes(:blob)
      .where(record_type: "Etablissement", record_id: etablissement_id_dossier_id.keys)
      .map do |a|
        dossier_id = etablissement_id_dossier_id[a.record_id]
        if @export_template
          dossier = dossiers.find { _1.id == dossier_id }
          [a, @export_template.attachment_path(dossier, a)]
        else
          ActiveStorage::DownloadableFile.pj_and_path(dossier_id, a)
        end
      end
  end

  def motivations(dossiers)
    ActiveStorage::Attachment
      .includes(:blob)
      .where(record_type: "Dossier", name: "justificatif_motivation", record_id: dossiers)
      .filter { |a| safe_attachment(a) }
      .map do |a|
        dossier_id = a.record_id
        if @export_template
          dossier = dossiers.find { _1.id == dossier_id }
          [a, @export_template.attachment_path(dossier, a)]
        else
          ActiveStorage::DownloadableFile.pj_and_path(dossier_id, a)
        end
      end
  end

  def attestations(dossiers)
    attestation_id_dossier_id = Attestation
      .joins(:pdf_attachment)
      .where(dossier: dossiers)
      .pluck(:id, :dossier_id)
      .to_h

    ActiveStorage::Attachment
      .includes(:blob)
      .where(record_type: "Attestation", record_id: attestation_id_dossier_id.keys)
      .map do |a|
        dossier_id = attestation_id_dossier_id[a.record_id]
        if @export_template
          dossier = dossiers.find { _1.id == dossier_id }
          [a, @export_template.attachment_path(dossier, a)]
        else
          ActiveStorage::DownloadableFile.pj_and_path(dossier_id, a)
        end
      end
  end

  def pjs_for_avis(dossiers)
    avis_ids_dossier_id_query = Avis.joins(:dossier).where(dossier: dossiers)
    if !liste_documents_allows?(:with_avis_piece_justificative)
      avis_ids_dossier_id_query = avis_ids_dossier_id_query.where(confidentiel: false)
    end
    if @user_profile.is_a?(Expert)
      avis_ids = Avis.joins(:dossier, experts_procedure: :expert)
        .where(experts_procedure: { expert: @user_profile })
        .where(dossier: dossiers)
        .pluck(:id)
      avis_ids_dossier_id_query = avis_ids_dossier_id_query.or(Avis.where(id: avis_ids))
    end
    avis_ids_dossier_id = avis_ids_dossier_id_query.pluck(:id, :dossier_id).to_h

    ActiveStorage::Attachment
      .includes(:blob)
      .where(record_type: "Avis", record_id: avis_ids_dossier_id.keys)
      .filter { |a| safe_attachment(a) }
      .map do |a|
        dossier_id = avis_ids_dossier_id[a.record_id]
        if @export_template
          dossier = dossiers.find { _1.id == dossier_id }
          [a, @export_template.attachment_path(dossier, a)]
        else
          ActiveStorage::DownloadableFile.pj_and_path(dossier_id, a)
        end
      end
  end

  def operation_logs_and_signature_ids(dossiers)
    dol_id_dossier_id_bill_id = DossierOperationLog
      .where(dossier: dossiers, data: nil)
      .pluck(:bill_signature_id, :id, :dossier_id)
    dol_id_data_bill_id = DossierOperationLog
      .where(dossier: dossiers)
      .with_data
      .pluck(:bill_signature_id, :id, :dossier_id, :data, :digest, :created_at)

    dol_id_dossier_id = dol_id_dossier_id_bill_id
      .map { |_, dol_id, dossier_id| [dol_id, dossier_id] }
      .to_h

    bill_ids = (dol_id_dossier_id_bill_id + dol_id_data_bill_id)
      .map(&:first)
      .uniq
      .compact

    serialized_dols = ActiveStorage::Attachment
      .includes(:blob)
      .where(record_type: "DossierOperationLog", record_id: dol_id_dossier_id.keys)
      .map do |a|
        dossier_id = dol_id_dossier_id[a.record_id]
        ActiveStorage::DownloadableFile.pj_and_path(dossier_id, a)
      end
    serialized_dols += dol_id_data_bill_id.map do |_, id, dossier_id, data, digest, created_at|
      a = ActiveStorage::FakeAttachment.new(
        file: StringIO.new(data.to_json),
        filename: "operation-#{digest}.json",
        name: 'serialized',
        id: id,
        created_at: created_at,
        record_type: 'DossierOperationLog'
      )
      ActiveStorage::DownloadableFile.pj_and_path(dossier_id, a)
    end

    [serialized_dols, bill_ids]
  end

  def signatures(bill_ids)
    ActiveStorage::Attachment
      .includes(:blob)
      .where(record_type: "BillSignature", record_id: bill_ids)
      .map { |bill| ActiveStorage::DownloadableFile.bill_and_path(bill) }
  end

  def safe_attachment(attachment)
    attachment
      .blob
      .virus_scan_result == ActiveStorage::VirusScanner::SAFE
  end

  def export_with_horodatage?
    return false if @user_profile.nil?

    Flipper.enabled?(:export_with_horodatage, @user_profile.user)
  end

  # given
  # repet_0 (stable_id: r0)
  # # row_0
  # # # pj_champ_0 (stable_id: 0)
  # # row_1
  # # # pj_champ_1 (stable_id: 0)
  # repet_1 (stable_id: r1)
  # # row_0
  # # # pj_champ_2 (stable_id: 1)
  # # # pj_champ_3 (stable_id: 2)
  # # row_1
  # # # pj_champ_4 (stable_id: 1)
  # # # pj_champ_5 (stable_id: 2)
  # it returns { pj_0.id => 0, pj_1.id => 1, pj_2.id => 0, pj_3.id => 0, pj_4.id => 1, pj_5.id => 1 }
  def compute_champ_id_row_index(champs)
    champs.filter(&:child?).group_by(&:dossier_id).values.each_with_object({}) do |children_for_dossier, hash|
      children_for_dossier.group_by(&:stable_id).values.each do |champs_for_stable_id|
        champs_for_stable_id.sort_by(&:row_id).each.with_index { |c, index| hash[c.id] = index }
      end
    end
  end
end
