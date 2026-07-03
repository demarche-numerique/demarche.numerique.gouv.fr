# frozen_string_literal: true

module DossierExportConcern
  extend ActiveSupport::Concern

  def spreadsheet_columns_csv(types_de_champ:, export_template: nil)
    spreadsheet_columns(with_etablissement: true, types_de_champ:, export_template:, format: :csv)
  end

  def spreadsheet_columns_xlsx(types_de_champ:, export_template: nil)
    spreadsheet_columns(types_de_champ:, export_template:, format: :xlsx)
  end

  def spreadsheet_columns_ods(types_de_champ:, export_template: nil)
    spreadsheet_columns(types_de_champ:, export_template:, format: :ods)
  end

  def champ_values_for_export(types_de_champ, row_id: nil, export_template: nil, format:)
    types_de_champ.flat_map do |type_de_champ|
      champ = filled_champ(type_de_champ, row_id:, with_discarded: true)
      if export_template.present?
        export_template
          .columns_for_stable_id(type_de_champ.stable_id)
          .map { |exported_column| exported_column.libelle_with_value(champ&.champ_data, format:) }
      else
        type_de_champ.libelles_for_export.map do |(libelle, path)|
          [libelle, type_de_champ.champ_value_for_export(champ, path)]
        end
      end
    end
  end

  def spreadsheet_columns(types_de_champ:, with_etablissement: false, export_template: nil, format: nil)
    Sentry.with_scope do |scope|
      scope.set_tags(dossier: id)
      dossier_values_for_export(with_etablissement:, export_template:, format:) + champ_values_for_export(types_de_champ, export_template:, format:)
    end
  end

  private

  def dossier_values_for_export(with_etablissement: false, export_template: nil, format:)
    if export_template.present?
      return export_template.dossier_exported_columns.map { _1.libelle_with_value(self, format:) }
    end

    columns = [
      ['ID', id.to_s],
      ['Email', user_email_for(:display)],
      ['FranceConnect ?', user_from_france_connect?],
    ]

    if procedure.for_individual?
      columns += [
        ['Civilité', individual&.gender],
        ['Nom', individual&.nom],
        ['Prénom', individual&.prenom],
        ['Dépôt pour un tiers', :for_tiers],
        ['Nom du mandataire', :mandataire_last_name],
        ['Prénom du mandataire', :mandataire_first_name],
      ]
      if procedure.ask_birthday
        columns += [['Date de naissance', individual&.birthdate]]
      end
    elsif with_etablissement
      columns += [
        ['Établissement SIRET', etablissement&.siret],
        ['Établissement siège social', etablissement&.siege_social],
        ['Établissement NAF', etablissement&.naf],
        ['Établissement libellé NAF', etablissement&.libelle_naf],
        ['Établissement Adresse', etablissement&.adresse],
        ['Établissement numero voie', etablissement&.numero_voie],
        ['Établissement type voie', etablissement&.type_voie],
        ['Établissement nom voie', etablissement&.nom_voie],
        ['Établissement complément adresse', etablissement&.complement_adresse],
        ['Établissement code postal', etablissement&.code_postal],
        ['Établissement localité', etablissement&.localite],
        ['Établissement code INSEE localité', etablissement&.code_insee_localite],
        ['Entreprise SIREN', etablissement&.entreprise_siren],
        ['Entreprise capital social', etablissement&.entreprise_capital_social],
        ['Entreprise numero TVA intracommunautaire', etablissement&.entreprise_numero_tva_intracommunautaire],
        ['Entreprise forme juridique', etablissement&.entreprise_forme_juridique],
        ['Entreprise forme juridique code', etablissement&.entreprise_forme_juridique_code],
        ['Entreprise nom commercial', etablissement&.entreprise_nom_commercial],
        ['Entreprise raison sociale', etablissement&.entreprise_raison_sociale],
        ['Entreprise SIRET siège social', etablissement&.entreprise_siret_siege_social],
        ['Entreprise code effectif entreprise', etablissement&.entreprise_code_effectif_entreprise],
        ['Entreprise date de création', etablissement&.entreprise_date_creation],
        ['Entreprise état administratif', etablissement&.entreprise_etat_administratif],
        ['Entreprise nom', etablissement&.entreprise_nom],
        ['Entreprise prénom', etablissement&.entreprise_prenom],
        ['Association RNA', etablissement&.association_rna],
        ['Association titre', etablissement&.association_titre],
        ['Association objet', etablissement&.association_objet],
        ['Association date de création', etablissement&.association_date_creation],
        ['Association date de déclaration', etablissement&.association_date_declaration],
        ['Association date de publication', etablissement&.association_date_publication],
      ]
    else
      columns << ['Entreprise raison sociale', etablissement&.entreprise_raison_sociale]
    end
    if procedure.chorusable? && procedure.chorus_configuration.complete?
      columns += [
        ['Domaine Fonctionnel', procedure.chorus_configuration.domaine_fonctionnel&.fetch("code") { '' }],
        ['Référentiel De Programmation', procedure.chorus_configuration.referentiel_de_programmation&.fetch("code") { '' }],
        ['Centre De Coût', procedure.chorus_configuration.centre_de_cout&.fetch("code") { '' }],
      ]
    end
    columns += [
      ['À archiver', :archived],
      ['État du dossier', Dossier.human_attribute_name("state.#{state}")],
      ['Dernière mise à jour le', :updated_at],
      ['Dernière mise à jour du dossier le', :last_champ_updated_at],
      ['Déposé le', :depose_at],
      ['Passé en instruction le', :en_instruction_at],
      procedure.sva_svr_enabled? ? ["Date décision #{procedure.sva_svr_configuration.human_decision}", :sva_svr_decision_on] : nil,
      ['Traité le', :processed_at],
      ['Motivation de la décision', :motivation],
      ['Instructeurs', followers_instructeurs.map(&:email).join(' ')],
    ].compact

    if procedure.routing_enabled?
      columns << ['Groupe instructeur', groupe_instructeur.label]
    end

    columns
  end
end
