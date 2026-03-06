# frozen_string_literal: true

class SerializerService
  def self.dossier(dossier)
    Sentry.with_scope do |scope|
      scope.set_tags(dossier: dossier.id)

      data = execute_query('serializeDossier', { number: dossier.id })
      data && data['dossier']
    end
  end

  def self.dossiers(procedure)
    Sentry.with_scope do |scope|
      scope.set_tags(procedure: procedure.id)

      data = execute_query('serializeDossiers', { number: procedure.id })
      data && data['demarche']['dossiers']
    end
  end

  def self.demarches_publiques(after: nil)
    data = execute_query('serializeDemarchesPubliques', { after: after })
    data && data['demarchesPubliques']
  end

  def self.avis(avis)
    data = execute_query('serializeAvis', { number: avis.dossier_id, id: avis.to_typed_id })
    data && data['dossier']['avis'].first
  end

  def self.champ(champ)
    Sentry.with_scope do |scope|
      scope.set_tags(champ: champ.id)

      if champ.private?
        data = execute_query('serializeAnnotation', { number: champ.dossier_id, id: champ.to_typed_id })
        data && data['dossier']['annotations'].first
      else
        data = execute_query('serializeChamp', { number: champ.dossier_id, id: champ.to_typed_id })
        data && data['dossier']['champs'].first
      end
    end
  end

  def self.message(commentaire)
    Sentry.with_scope do |scope|
      scope.set_tags(dossier: commentaire.dossier_id)

      data = execute_query('serializeMessage', { number: commentaire.dossier_id, id: commentaire.to_typed_id })
      data && data['dossier']["messages"].first
    end
  end

  def self.execute_query(operation_name, variables)
    result = API::V2::Schema.execute(QUERY,
      variables: variables,
      context: { internal_use: true },
      operation_name: operation_name)
    if result['errors'].present?
      error_message = result['errors'].first['message']
      Sentry.capture_message("SerializerService execute_query failed: " + error_message)
      raise error_message
    end
    result['data']
  end

  QUERY = <<-'GRAPHQL'
    query serializeDossiers($number: Int!, $after: String) {
      demarche(number: $number) {
        dossiers(after: $after) {
          nodes {
            ...DossierFragment
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    }

    query serializeDemarchesPubliques($after: String) {
      demarchesPubliques(after: $after) {
        nodes {
          ...DemarcheDescriptorFragment
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }

    query serializeDossier($number: Int!) {
      dossier(number: $number) {
        ...DossierFragment
      }
    }

    query serializeAvis($number: Int!, $id: ID!) {
      dossier(number: $number) {
        avis(id: $id) {
          ...AvisFragment
        }
      }
    }

    query serializeChamp($number: Int!, $id: ID!) {
      dossier(number: $number) {
        champs(id: $id) {
          ...ChampFragment
          ...RepetitionChampFragment
          ...CarteChampFragment
        }
      }
    }

    query serializeAnnotation($number: Int!, $id: ID!) {
      dossier(number: $number) {
        annotations(id: $id) {
          ...ChampFragment
          ...RepetitionChampFragment
          ...CarteChampFragment
        }
      }
    }

    query serializeMessage($number: Int!, $id: ID!) {
      dossier(number: $number) {
        messages(id: $id) {
          ...MessageFragment
        }
      }
    }

    fragment DossierFragment on Dossier {
      id
      number
      archived
      state
      dateDerniereModification
      datePassageEnConstruction
      datePassageEnInstruction
      dateTraitement
      dateDepot
      dateSuppressionParUsager
      dateSuppressionParAdministration
      instructeurs {
        email
      }
      groupeInstructeur {
        label
      }
      champs {
        ...ChampFragment
        ...RepetitionChampFragment
        ...CarteChampFragment
      }
      annotations {
        ...ChampFragment
        ...RepetitionChampFragment
        ...CarteChampFragment
      }
      avis {
        ...AvisFragment
      }
      demandeur {
        ...PersonnePhysiqueFragment
        ...PersonneMoraleFragment
        ...PersonneMoraleIncompleteFragment
      }
      motivation
      motivationAttachment {
        ...FileFragment
      }
      demarche {
        number
        revision {
          id
        }
      }
    }

    fragment AvisFragment on Avis {
      id
      question
      reponse
      dateQuestion
      dateReponse
      claimant {
        email
      }
      expert {
        email
      }
      attachment {
        ...FileFragment
      }
    }

    fragment ChampFragment on Champ {
      id
      label
      stringValue
      ... on SiretChamp {
        etablissement {
          ...PersonneMoraleFragment
        }
      }
      ... on LinkedDropDownListChamp {
        primaryValue
        secondaryValue
      }
      ... on MultipleDropDownListChamp {
        values
      }
      ... on PieceJustificativeChamp {
        file {
          ...FileFragment
        }
      }
      ... on AddressChamp {
        address {
          ...AddressFragment
        }
      }
      ... on CommuneChamp {
        commune {
          name
          code
        }
        departement {
          name
          code
        }
      }
      ... on DepartementChamp {
        departement {
          name
          code
        }
      }
      ... on RegionChamp {
        region {
          name
          code
        }
      }
    }

    fragment RepetitionChampFragment on RepetitionChamp {
      rows {
        champs {
          ...ChampFragment
        }
      }
    }

    fragment CarteChampFragment on CarteChamp {
      geoAreas {
        source
        description
        geometry {
          type
          coordinates
        }
        ... on ParcelleCadastrale {
          prefixe
          numero
          commune
          section
          surface
        }
      }
    }

    fragment PersonnePhysiqueFragment on PersonnePhysique {
      civilite
      nom
      prenom
      dateDeNaissance
    }

    fragment PersonneMoraleFragment on PersonneMorale {
      siret
      siegeSocial
      naf
      libelleNaf
      address {
        ...AddressFragment
      }
      entreprise {
        siren
        capitalSocial
        numeroTvaIntracommunautaire
        formeJuridique
        formeJuridiqueCode
        nomCommercial
        raisonSociale
        siretSiegeSocial
        codeEffectifEntreprise
        dateCreation
        nom
        prenom
      }
      association {
        rna
        titre
        objet
        dateCreation
        dateDeclaration
        datePublication
      }
    }

    fragment PersonneMoraleIncompleteFragment on PersonneMoraleIncomplete {
      siret
    }

    fragment AddressFragment on Address {
      label
      type
      streetAddress
      streetNumber
      streetName
      postalCode
      cityName
      cityCode
      departmentName
      departmentCode
      regionName
      regionCode
    }

    fragment FileFragment on File {
      filename
      checksum
      byteSize: byteSizeBigInt
      contentType
      virusScanResult
    }

    fragment ChampDescriptorFragment on ChampDescriptor {
      __typename
      label
      description
      required
      ... on DropDownListChampDescriptor {
        options
        otherOption
      }
      ... on MultipleDropDownListChampDescriptor {
        options
      }
      ... on LinkedDropDownListChampDescriptor {
        options
      }
    }

    fragment DemarcheDescriptorFragment on DemarcheDescriptor {
      number
      title
      description
      state
      forIndividual
      tags
      zones
      datePublication
      service { nom organisme typeOrganisme }
      demarcheUrl
      dpoUrl
      noticeUrl
      siteWebUrl
      cadreJuridiqueUrl
      logo { ...FileFragment }
      notice { ...FileFragment }
      deliberation { ...FileFragment }
      dossiersCount
      revision {
        champDescriptors {
          ...ChampDescriptorFragment
          ... on RepetitionChampDescriptor {
            champDescriptors {
              ...ChampDescriptorFragment
            }
          }
        }
      }
    }

    fragment MessageFragment on Message {
      id
      email
      body
      createdAt
      attachments {
        ...FileFragment
      }
    }
  GRAPHQL
end
