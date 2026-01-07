# frozen_string_literal: true

class API::V2::StoredQuery
  def self.get(query_id)
    case query_id
    when 'ds-query-v2'
      QUERY_V2
    when 'ds-mutation-v2'
      MUTATION_V2
    when 'introspection'
      GraphQL::Introspection::INTROSPECTION_QUERY
    else
      raise GraphQL::ExecutionError.new("No query with id \"#{query_id}\"", extensions: { code: :bad_request })
    end
  end

  QUERY_V2 = <<-'GRAPHQL'
  query getDemarche(
    $demarcheNumber: Int!
    $state: DossierState
    $order: Order
    $first: Int
    $last: Int
    $before: String
    $after: String
    $archived: Boolean
    $revision: ID
    $createdSince: ISO8601DateTime
    $updatedSince: ISO8601DateTime
    $pendingDeletedFirst: Int
    $pendingDeletedLast: Int
    $pendingDeletedBefore: String
    $pendingDeletedAfter: String
    $pendingDeletedSince: ISO8601DateTime
    $deletedFirst: Int
    $deletedLast: Int
    $deletedBefore: String
    $deletedAfter: String
    $deletedSince: ISO8601DateTime
    $includeGroupeInstructeurs: Boolean = false
    $includeDossiers: Boolean = false
    $includePendingDeletedDossiers: Boolean = false
    $includeDeletedDossiers: Boolean = false
    $includeRevision: Boolean = false
    $includeRevisions: Boolean = false
    $includeService: Boolean = false
    $includeChamps: Boolean = true
    $includeAnotations: Boolean = true
    $includeTraitements: Boolean = true
    $includeInstructeurs: Boolean = true
    $includeAvis: Boolean = false
    $includeMessages: Boolean = false
    $includeCorrections: Boolean = false
    $includeGeometry: Boolean = false
  ) {
    demarche(number: $demarcheNumber) {
      id
      number
      title
      state
      declarative
      dateCreation
      dateFermeture
      chorusConfiguration {
        centreDeCout
        domaineFonctionnel
        referentielDeProgrammation
      }
      activeRevision @include(if: $includeRevision) {
        ...RevisionFragment
      }
      revisions @include(if: $includeRevisions) {
        ...RevisionFragment
      }
      groupeInstructeurs @include(if: $includeGroupeInstructeurs) {
        ...GroupeInstructeurFragment
      }
      service @include(if: $includeService) {
        ...ServiceFragment
      }
      dossiers(
        state: $state
        order: $order
        first: $first
        last: $last
        before: $before
        after: $after
        archived: $archived
        createdSince: $createdSince
        updatedSince: $updatedSince
        revision: $revision
      ) @include(if: $includeDossiers) {
        pageInfo {
          ...PageInfoFragment
        }
        nodes {
          ...DossierFragment
        }
      }
      pendingDeletedDossiers(
        first: $pendingDeletedFirst
        last: $pendingDeletedLast
        before: $pendingDeletedBefore
        after: $pendingDeletedAfter
        deletedSince: $pendingDeletedSince
      ) @include(if: $includePendingDeletedDossiers) {
        pageInfo {
          ...PageInfoFragment
        }
        nodes {
          ...DeletedDossierFragment
        }
      }
      deletedDossiers(
        first: $deletedFirst
        last: $deletedLast
        before: $deletedBefore
        after: $deletedAfter
        deletedSince: $deletedSince
      ) @include(if: $includeDeletedDossiers) {
        pageInfo {
          ...PageInfoFragment
        }
        nodes {
          ...DeletedDossierFragment
        }
      }
    }
  }

  query getGroupeInstructeur(
    $groupeInstructeurNumber: Int!
    $state: DossierState
    $order: Order
    $first: Int
    $last: Int
    $before: String
    $after: String
    $archived: Boolean
    $revision: ID
    $createdSince: ISO8601DateTime
    $updatedSince: ISO8601DateTime
    $pendingDeletedOrder: Order
    $pendingDeletedFirst: Int
    $pendingDeletedLast: Int
    $pendingDeletedBefore: String
    $pendingDeletedAfter: String
    $pendingDeletedSince: ISO8601DateTime
    $deletedOrder: Order
    $deletedFirst: Int
    $deletedLast: Int
    $deletedBefore: String
    $deletedAfter: String
    $deletedSince: ISO8601DateTime
    $includeDossiers: Boolean = false
    $includePendingDeletedDossiers: Boolean = false
    $includeDeletedDossiers: Boolean = false
    $includeChamps: Boolean = true
    $includeAnotations: Boolean = true
    $includeTraitements: Boolean = true
    $includeInstructeurs: Boolean = true
    $includeAvis: Boolean = false
    $includeMessages: Boolean = false
    $includeCorrections: Boolean = false
    $includeGeometry: Boolean = false
  ) {
    groupeInstructeur(number: $groupeInstructeurNumber) {
      id
      number
      label
      instructeurs @include(if: $includeInstructeurs) {
        id
        email
      }
      dossiers(
        state: $state
        order: $order
        first: $first
        last: $last
        before: $before
        after: $after
        archived: $archived
        createdSince: $createdSince
        updatedSince: $updatedSince
        revision: $revision
      ) @include(if: $includeDossiers) {
        pageInfo {
          ...PageInfoFragment
        }
        nodes {
          ...DossierFragment
        }
      }
      pendingDeletedDossiers(
        order: $pendingDeletedOrder
        first: $pendingDeletedFirst
        last: $pendingDeletedLast
        before: $pendingDeletedBefore
        after: $pendingDeletedAfter
        deletedSince: $pendingDeletedSince
      ) @include(if: $includePendingDeletedDossiers) {
        pageInfo {
          ...PageInfoFragment
        }
        nodes {
          ...DeletedDossierFragment
        }
      }
      deletedDossiers(
        order: $deletedOrder
        first: $deletedFirst
        last: $deletedLast
        before: $deletedBefore
        after: $deletedAfter
        deletedSince: $deletedSince
      ) @include(if: $includeDeletedDossiers) {
        pageInfo {
          ...PageInfoFragment
        }
        nodes {
          ...DeletedDossierFragment
        }
      }
    }
  }

  query getDossier(
    $dossierNumber: Int!
    $includeRevision: Boolean = false
    $includeService: Boolean = false
    $includeChamps: Boolean = true
    $includeAnotations: Boolean = true
    $includeTraitements: Boolean = true
    $includeInstructeurs: Boolean = true
    $includeAvis: Boolean = false
    $includeMessages: Boolean = false
    $includeCorrections: Boolean = false
    $includeGeometry: Boolean = false
  ) {
    dossier(number: $dossierNumber) {
      ...DossierFragment
      demarche {
        ...DemarcheDescriptorFragment
      }
    }
  }

  query getDemarcheDescriptor(
    $demarche: FindDemarcheInput!
    $includeRevision: Boolean = false
    $includeService: Boolean = false
  ) {
    demarcheDescriptor(demarche: $demarche) {
      ...DemarcheDescriptorFragment
    }
  }

  fragment ServiceFragment on Service {
    nom
    siret
    organisme
    typeOrganisme
  }

  fragment GroupeInstructeurFragment on GroupeInstructeur {
    id
    number
    label
    instructeurs @include(if: $includeInstructeurs) {
      id
      email
    }
  }

  fragment DossierFragment on Dossier {
    __typename
    id
    number
    archived
    prefilled
    state
    dateDerniereModification
    dateDepot
    datePassageEnConstruction
    datePassageEnInstruction
    dateTraitement
    dateExpiration
    dateSuppressionParUsager
    dateDerniereCorrectionEnAttente @include(if: $includeCorrections)
    dateDerniereModificationChamps
    dateDerniereModificationAnnotations
    motivation
    motivationAttachment {
      ...FileFragment
    }
    attestation {
      ...FileFragment
    }
    pdf {
      ...FileFragment
    }
    usager {
      email
    }
    prenomMandataire
    nomMandataire
    deposeParUnTiers
    connectionUsager
    groupeInstructeur {
      ...GroupeInstructeurFragment
    }
    demandeur {
      __typename
      ...PersonnePhysiqueFragment
      ...PersonneMoraleFragment
      ...PersonneMoraleIncompleteFragment
    }
    demarche {
      revision {
        id
      }
    }
    instructeurs @include(if: $includeInstructeurs) {
      id
      email
    }
    traitements @include(if: $includeTraitements) {
      event
      emailAgentTraitant
      dateTraitement
      motivation
      revision {
        id
        datePublication
      }
    }
    champs @include(if: $includeChamps) {
      ...ChampFragment
      ...RootChampFragment
    }
    annotations @include(if: $includeAnotations) {
      ...ChampFragment
      ...RootChampFragment
    }
    avis @include(if: $includeAvis) {
      ...AvisFragment
    }
    messages @include(if: $includeMessages) {
      ...MessageFragment
    }
  }

  fragment DemarcheDescriptorFragment on DemarcheDescriptor {
    id
    number
    title
    description
    state
    declarative
    dateCreation
    datePublication
    dateDerniereModification
    dateDepublication
    dateFermeture
    notice { url }
    deliberation { url }
    demarcheURL
    cadreJuridiqueURL
    service @include(if: $includeService) {
      ...ServiceFragment
    }
    revision @include(if: $includeRevision) {
      ...RevisionFragment
    }
  }

  fragment DeletedDossierFragment on DeletedDossier {
    id
    number
    dateSupression
    state
    reason
  }

  fragment RevisionFragment on Revision {
    id
    datePublication
    champDescriptors {
      ...ChampDescriptorFragment
      ... on RepetitionChampDescriptor {
        champDescriptors {
          ...ChampDescriptorFragment
        }
      }
    }
    annotationDescriptors {
      ...ChampDescriptorFragment
      ... on RepetitionChampDescriptor {
        champDescriptors {
          ...ChampDescriptorFragment
        }
      }
    }
  }

  fragment ChampDescriptorFragment on ChampDescriptor {
    __typename
    id
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
    ... on PieceJustificativeChampDescriptor {
      fileTemplate {
        ...FileFragment
      }
    }
    ... on ExplicationChampDescriptor {
      collapsibleExplanationEnabled
      collapsibleExplanationText
    }
    ... on HeaderSectionChampDescriptor {
      level
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
    attachments {
      ...FileFragment
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
    correction @include(if: $includeCorrections) {
      reason
      dateResolution
    }
  }

  fragment GeoAreaFragment on GeoArea {
    id
    source
    description
    geometry @include(if: $includeGeometry) {
      type
      coordinates
    }
    ... on ParcelleCadastrale {
      commune
      numero
      section
      prefixe
      surface
    }
  }

  fragment RootChampFragment on Champ {
    ... on RepetitionChamp {
      rows {
        id
        champs {
          ...ChampFragment
        }
      }
    }
    ... on CarteChamp {
      geoAreas {
        ...GeoAreaFragment
      }
    }
    ... on DossierLinkChamp {
      dossier {
        id
        number
        state
      }
    }
  }

  fragment ChampFragment on Champ {
    id
    champDescriptorId
    __typename
    label
    stringValue
    updatedAt
    prefilled
    columns {
      ...ColumnFragment
    }
    ... on DateChamp {
      date
    }
    ... on DatetimeChamp {
      datetime
    }
    ... on CheckboxChamp {
      checked: value
    }
    ... on YesNoChamp {
      selected: value
    }
    ... on DecimalNumberChamp {
      decimalNumber: value
    }
    ... on IntegerNumberChamp {
      integerNumber: value
    }
    ... on CiviliteChamp {
      civilite: value
    }
    ... on LinkedDropDownListChamp {
      primaryValue
      secondaryValue
    }
    ... on DropDownListChamp {
      value
    }
    ... on MultipleDropDownListChamp {
      values
    }
    ... on PieceJustificativeChamp {
      files {
        ...FileFragment
      }
    }
    ... on AddressChamp {
      address {
        ...AddressFragment
      }
      commune {
        ...CommuneFragment
      }
      departement {
        ...DepartementFragment
      }
    }
    ... on EpciChamp {
      epci {
        ...EpciFragment
      }
      departement {
        ...DepartementFragment
      }
    }
    ... on CommuneChamp {
      commune {
        ...CommuneFragment
      }
      departement {
        ...DepartementFragment
      }
    }
    ... on DepartementChamp {
      departement {
        ...DepartementFragment
      }
    }
    ... on RegionChamp {
      region {
        ...RegionFragment
      }
    }
    ... on PaysChamp {
      pays {
        ...PaysFragment
      }
    }
    ... on SiretChamp {
      etablissement {
        ...PersonneMoraleFragment
      }
    }
    ... on RNFChamp {
      rnf {
        ...RNFFragment
      }
      commune {
        ...CommuneFragment
      }
      departement {
        ...DepartementFragment
      }
    }
    ... on EngagementJuridiqueChamp {
      engagementJuridique {
        ...EngagementJuridiqueFragment
      }
    }
    ... on HeaderSectionChamp {
      level
    }
    ... on ExplicationChamp {
      __typename
    }
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
      attestationFiscaleAttachment {
        ...FileFragment
      }
      attestationSocialeAttachment {
        ...FileFragment
      }
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

  fragment PersonnePhysiqueFragment on PersonnePhysique {
    civilite
    nom
    prenom
    email
  }


  fragment FileFragment on File {
    __typename
    filename
    contentType
    checksum
    byteSize: byteSizeBigInt
    url
    createdAt
    virusScanResult
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

  fragment PaysFragment on Pays {
    name
    code
  }

  fragment RegionFragment on Region {
    name
    code
  }

  fragment DepartementFragment on Departement {
    name
    code
  }

  fragment EpciFragment on Epci {
    name
    code
  }

  fragment CommuneFragment on Commune {
    name
    code
    postalCode
  }

  fragment RNFFragment on RNF {
    id
    title
    address {
      ...AddressFragment
    }
  }

  fragment EngagementJuridiqueFragment on EngagementJuridique {
    montantEngage
    montantPaye
  }

  fragment PageInfoFragment on PageInfo {
    hasPreviousPage
    hasNextPage
    startCursor
    endCursor
  }

  fragment ColumnFragment on Column {
    __typename
    id
    label
    ... on TextColumn {
      value
    }
    ... on BooleanColumn {
      value
    }
    ... on DateColumn {
      value
    }
    ... on DateTimeColumn {
      value
    }
    ... on IntegerColumn {
      value
    }
    ... on DecimalColumn {
      value
    }
    ... on EnumColumn {
      value
    }
    ... on EnumsColumn {
      value
    }
    ... on AttachmentsColumn {
      value {
        ...FileFragment
      }
    }
  }
  GRAPHQL

  MUTATION_V2 = <<-'GRAPHQL'
  mutation dossierArchiver($input: DossierArchiverInput!) {
    dossierArchiver(input: $input) {
      dossier {
        id
        archived
      }
      errors {
        message
      }
    }
  }

  mutation dossierDesarchiver($input: DossierDesarchiverInput!) {
    dossierDesarchiver(input: $input) {
      dossier {
        id
        archived
      }
      errors {
        message
      }
    }
  }

  mutation dossierPasserEnInstruction($input: DossierPasserEnInstructionInput!) {
    dossierPasserEnInstruction(input: $input) {
      dossier {
        id
        state
      }
      errors {
        message
      }
    }
  }

  mutation dossierRepasserEnConstruction(
    $input: DossierRepasserEnConstructionInput!
  ) {
    dossierRepasserEnConstruction(input: $input) {
      dossier {
        id
        state
      }
      errors {
        message
      }
    }
  }

  mutation dossierAccepter($input: DossierAccepterInput!) {
    dossierAccepter(input: $input) {
      dossier {
        id
        state
        attestation {
          url
        }
      }
      errors {
        message
      }
    }
  }

  mutation dossierBasculeSuivi($input: DossierBasculeSuiviInput!) {
    dossierBasculeSuivi(input: $input) {
      dossier {
        id
        instructeurs {
          id
        }
      }
      instructeur {
        id
      }
      errors {
        message
      }
    }
  }

  mutation dossierRefuser($input: DossierRefuserInput!) {
    dossierRefuser(input: $input) {
      dossier {
        id
        state
        attestation {
          url
        }
      }
      errors {
        message
      }
    }
  }

  mutation dossierClasserSansSuite($input: DossierClasserSansSuiteInput!) {
    dossierClasserSansSuite(input: $input) {
      dossier {
        id
        state
      }
      errors {
        message
      }
    }
  }

  mutation dossierRepasserEnInstruction(
    $input: DossierRepasserEnInstructionInput!
  ) {
    dossierRepasserEnInstruction(input: $input) {
      dossier {
        id
        state
      }
      errors {
        message
      }
    }
  }

  mutation dossierEnvoyerMessage($input: DossierEnvoyerMessageInput!) {
    dossierEnvoyerMessage(input: $input) {
      message {
        id
        createdAt
      }
      errors {
        message
      }
    }
  }

  mutation dossierSupprimerMessage($input: DossierSupprimerMessageInput!) {
    dossierSupprimerMessage(input: $input) {
      message {
        id
        createdAt
        discardedAt
      }
      errors {
        message
      }
    }
  }

  mutation dossierAnnulerDemandeCorrection($input: DossierAnnulerDemandeCorrectionInput!) {
    dossierAnnulerDemandeCorrection(input: $input) {
      message {
        id
        createdAt
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotationText(
    $input: DossierModifierAnnotationTextInput!
  ) {
    dossierModifierAnnotationText(input: $input) {
      annotation {
        id
        value: stringValue
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotationCheckbox(
    $input: DossierModifierAnnotationCheckboxInput!
  ) {
    dossierModifierAnnotationCheckbox(input: $input) {
      annotation {
        id
        ... on CheckboxChamp {
          value
        }
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotationDate(
    $input: DossierModifierAnnotationDateInput!
  ) {
    dossierModifierAnnotationDate(input: $input) {
      annotation {
        id
        ... on DateChamp {
          value: date
        }
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotationDateTime(
    $input: DossierModifierAnnotationDatetimeInput!
  ) {
    dossierModifierAnnotationDatetime(input: $input) {
      annotation {
        id
        ... on DatetimeChamp {
          value: datetime
        }
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotationDropDownList(
    $input: DossierModifierAnnotationDropDownListInput!
  ) {
    dossierModifierAnnotationDropDownList(input: $input) {
      annotation {
        id
        value: stringValue
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotationIntegerNumber(
    $input: DossierModifierAnnotationIntegerNumberInput!
  ) {
    dossierModifierAnnotationIntegerNumber(input: $input) {
      annotation {
        id
        ... on IntegerNumberChamp {
          value
        }
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotationDecimalNumber(
    $input: DossierModifierAnnotationDecimalNumberInput!
  ) {
    dossierModifierAnnotationDecimalNumber(input: $input) {
      annotation {
        id
        ... on DecimalNumberChamp {
          value
        }
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotationAjouterLigne(
    $input: DossierModifierAnnotationAjouterLigneInput!
  ) {
    dossierModifierAnnotationAjouterLigne(input: $input) {
      annotation {
        id
      }
      errors {
        message
      }
    }
  }

  mutation dossierModifierAnnotations(
    $input: DossierModifierAnnotationsInput!
  ) {
    dossierModifierAnnotations(input: $input) {
      annotations {
        id
      }
      errors {
        message
      }
    }
  }

  mutation createDirectUpload($input: CreateDirectUploadInput!) {
    createDirectUpload(input: $input) {
      directUpload {
        signedBlobId
        headers
        url
      }
    }
  }

  mutation groupeInstructeurModifier($input: GroupeInstructeurModifierInput!) {
    groupeInstructeurModifier(input: $input) {
      groupeInstructeur {
        id
      }
      errors {
        message
      }
    }
  }

  mutation groupeInstructeurCreer($input: GroupeInstructeurCreerInput!, $includeInstructeurs: Boolean = false) {
    groupeInstructeurCreer(input: $input) {
      groupeInstructeur {
        id
        instructeurs @include(if: $includeInstructeurs) {
          id
          email
        }
      }
      errors {
        message
      }
      warnings {
        message
      }
    }
  }

  mutation groupeInstructeurAjouterInstructeurs($input: GroupeInstructeurAjouterInstructeursInput!, $includeInstructeurs: Boolean = false) {
    groupeInstructeurAjouterInstructeurs(input: $input) {
      groupeInstructeur {
        id
        instructeurs @include(if: $includeInstructeurs) {
          id
          email
        }
      }
      errors {
        message
      }
      warnings {
        message
      }
    }
  }

  mutation groupeInstructeurSupprimerInstructeurs($input: GroupeInstructeurSupprimerInstructeursInput!, $includeInstructeurs: Boolean = false) {
    groupeInstructeurSupprimerInstructeurs(input: $input) {
      groupeInstructeur {
        id
        instructeurs @include(if: $includeInstructeurs) {
          id
          email
        }
      }
      errors {
        message
      }
    }
  }

  mutation demarcheCloner($input: DemarcheClonerInput!) {
    demarcheCloner(input: $input) {
      demarche {
        id
        number
      }
      errors {
        message
      }
    }
  }
  GRAPHQL
end
