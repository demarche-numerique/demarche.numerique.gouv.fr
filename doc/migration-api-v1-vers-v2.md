# Migration de l’API v1 vers l’API v2

L’API v1 (REST/JSON) est supprimée. Ce document donne, pour **chaque endpoint et
chaque attribut de la v1**, la requête GraphQL v2 équivalente.

- **Ancienne API** : `GET /api/v1/...`, réponses JSON figées.
- **Nouvelle API** : `POST /api/v2/graphql`, une seule URL, vous choisissez les
  champs que vous recevez.

> Les jetons d’API existants continuent de fonctionner : c’est le **même jeton**
> pour la v1 et la v2, aucune régénération n’est nécessaire.

---

## 1. Ce qui change en profondeur

| Sujet | API v1 | API v2 |
|---|---|---|
| Protocole | REST, 3 endpoints | GraphQL, 1 endpoint `POST /api/v2/graphql` |
| Authentification | En-tête `Authorization: Bearer <jeton>` **ou** `?token=<jeton>` dans l’URL | En-tête `Authorization: Bearer <jeton>` **uniquement** |
| Sélection des données | Imposée par le serveur | Vous listez les champs voulus dans la requête |
| Identifiants | Entiers (`id`) | `number` (entier, équivalent de l’`id` v1) **et** `id` (chaîne opaque, *GlobalID*) |
| Pagination | `?page=1&resultats_par_page=100` | Curseurs Relay (`first`, `after`, `pageInfo`) |
| Dates | Converties en UTC | Format ISO 8601 avec fuseau |
| Erreurs | Code HTTP (`401`, `404`) | HTTP `200` + tableau `errors` dans le corps |

### Le passage du paramètre `token` dans l’URL n’existe plus

La v1 acceptait le jeton en paramètre d’URL. C’était une faille de
confidentialité (le jeton se retrouvait dans les journaux serveur et les
en-têtes `Referer`). La v2 exige l’en-tête HTTP :

```bash
curl -X POST https://www.demarches-simplifiees.fr/api/v2/graphql \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "{ demarche(number: 123) { title } }"}'
```

### Deux identifiants au lieu d’un

C’est **le principal piège de la migration**. Là où la v1 renvoyait un `id`
entier, la v2 expose deux champs :

- `number` : l’entier, **identique à l’`id` de la v1**. C’est celui à utiliser
  pour retrouver vos correspondances existantes.
- `id` : une chaîne opaque encodée en base64, utilisée par GraphQL pour les
  requêtes internes et les mutations.

Pour les **champs** (`champs`), la v1 renvoyait `type_de_champ.id`, qui valait
le `stable_id` (entier). En v2, l’équivalent stable est
**`champDescriptorId`** (chaîne). Si votre code fait correspondre les champs par
identifiant, c’est le point à retravailler en priorité.

---

## 2. Correspondance des endpoints

| Endpoint v1 | Requête v2 |
|---|---|
| `GET /api/v1/procedures/:id` | `query { demarche(number: $id) { … } }` |
| `GET /api/v1/procedures/:procedure_id/dossiers` | `query { demarche(number: $id) { dossiers { … } } }` |
| `GET /api/v1/procedures/:procedure_id/dossiers/:id` | `query { dossier(number: $id) { … } }` |

---

## 3. Récupérer une démarche

### v1

```
GET /api/v1/procedures/123
```

### v2

```graphql
query getDemarche($demarcheNumber: Int!) {
  demarche(number: $demarcheNumber) {
    number
    title
    description
    state
    dateFermeture
    service {
      nom
      typeOrganisme
      organisme
      siret
      departement
    }
    activeRevision {
      champDescriptors {
        __typename
        id
        label
        description
        required
      }
      annotationDescriptors {
        __typename
        id
        label
        description
        required
      }
    }
  }
}
```

Variables : `{ "demarcheNumber": 123 }`

### Correspondance des attributs

| Attribut v1 | Équivalent v2 | Remarque |
|---|---|---|
| `id` | `number` | Valeur identique |
| `label` | `title` | Renommé (`libelle` en base) |
| `description` | `description` | |
| `organisation` | `service.organisme` | |
| `state` | `state` | Mêmes valeurs : `brouillon`, `publiee`, `close`, `depubliee` |
| `archived_at` | `dateFermeture` | |
| `link` | `demarcheDescriptor(demarche: { number: … }) { demarcheURL }` | Voir ci-dessous |
| `types_de_champ` | `activeRevision.champDescriptors` | |
| `types_de_champ_private` | `activeRevision.annotationDescriptors` | |
| `service` | `service` | Voir § 3.2 : plusieurs attributs ont disparu |
| `direction` | — | Valait toujours `""` en v1 |
| `total_dossier` | — | **Pas d’équivalent**, voir § 8 |
| `geographic_information` | — | Module carto historique, supprimé |
| `types_de_piece_justificative` | — | Pièces justificatives historiques, supprimées |

L’URL publique de la démarche est exposée par une requête distincte :

```graphql
query { demarcheDescriptor(demarche: { number: 123 }) { demarcheURL } }
```

### 3.1 Types de champ → `ChampDescriptor`

| Attribut v1 | Équivalent v2 | Remarque |
|---|---|---|
| `id` | `champDescriptorId` (côté champ) / `id` (côté descripteur) | La v1 renvoyait le `stable_id` entier |
| `libelle` | `label` | |
| `description` | `description` | |
| `type_champ` | `__typename` | `type` existe encore mais est **déprécié** |
| `order_place` | — | Valait toujours `-1` en v1 ; l’ordre est celui du tableau |
| — | `required` | Nouveau : champ obligatoire ou non |

### 3.2 Service

| Attribut v1 | Équivalent v2 |
|---|---|
| `name` | `nom` |
| `type_organization` | `typeOrganisme` |
| `organization` | `organisme` |
| `siret` | `siret` |
| `email` | **Aucun équivalent** |
| `phone` | **Aucun équivalent** |
| `schedule` | **Aucun équivalent** |
| `address` | **Aucun équivalent** |
| — | `departement` (nouveau) |

> Les coordonnées du service (courriel, téléphone, horaires, adresse) ne sont
> pas exposées par l’API v2. Si votre intégration en dépend, signalez-le au
> support avant de basculer.

---

## 4. Lister les dossiers d’une démarche

### v1

```
GET /api/v1/procedures/123/dossiers?page=1&resultats_par_page=100&order=asc
```

### v2

```graphql
query getDossiers($demarcheNumber: Int!, $after: String) {
  demarche(number: $demarcheNumber) {
    dossiers(first: 100, after: $after) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        number
        state
        dateDepot
        dateDerniereModification
      }
    }
  }
}
```

### Correspondance des attributs

| Attribut v1 | Équivalent v2 |
|---|---|
| `id` | `number` |
| `updated_at` | `dateDerniereModification` |
| `initiated_at` | `dateDepot` |
| `state` | `state` (valeurs différentes, voir § 6) |

### Pagination : de `page` aux curseurs

La v1 utilisait des numéros de page ; la v2 utilise des curseurs. Le principe :
on demande les `first: N` premiers résultats, puis on repasse `endCursor` dans
`after` tant que `hasNextPage` vaut `true`.

| v1 | v2 |
|---|---|
| `?page=2` | `after: "<endCursor de la page précédente>"` |
| `?resultats_par_page=100` | `first: 100` |
| `?order=asc` (défaut) | ordre par défaut |
| `?order=desc` | `last: 100` (l’argument `order` est déprécié) |
| `pagination.nombre_de_page` | `pageInfo.hasNextPage` (booléen, pas un total) |

Exemple de boucle de pagination :

```bash
AFTER=null
while : ; do
  RESP=$(curl -sX POST https://www.demarches-simplifiees.fr/api/v2/graphql \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"query\":\"query(\$after:String){demarche(number:123){dossiers(first:100,after:\$after){pageInfo{hasNextPage endCursor} nodes{number state}}}}\",\"variables\":{\"after\":$AFTER}}")
  echo "$RESP" | jq '.data.demarche.dossiers.nodes[]'
  [ "$(echo "$RESP" | jq -r '.data.demarche.dossiers.pageInfo.hasNextPage')" = "true" ] || break
  AFTER=$(echo "$RESP" | jq '.data.demarche.dossiers.pageInfo.endCursor')
done
```

### Filtres : ce que la v2 apporte en plus

La v1 obligeait à tout récupérer puis à filtrer côté client. La v2 filtre côté
serveur :

```graphql
query getDossiersFiltres($demarcheNumber: Int!) {
  demarche(number: $demarcheNumber) {
    dossiers(
      first: 100
      state: en_instruction # un seul état à la fois
      createdSince: "2026-01-01T00:00:00+01:00"
      updatedSince: "2026-07-01T00:00:00+02:00"
      archived: false
    ) {
      nodes { number }
    }
  }
}
```

C’est le principal gain de la migration : une synchronisation incrémentale
avec `updatedSince` remplace le parcours complet de toutes les pages.

---

## 5. Récupérer un dossier

### v1

```
GET /api/v1/procedures/123/dossiers/456
```

### v2

```graphql
query getDossier($dossierNumber: Int!) {
  dossier(number: $dossierNumber) {
    number
    state
    archived
    dateDepot
    datePassageEnConstruction
    datePassageEnInstruction
    dateTraitement
    dateDerniereModification
    motivation
    motivationAttachment { url filename }
    attestation { url }

    usager { email }
    instructeurs { email }

    demandeur {
      __typename
      ... on PersonnePhysique {
        civilite
        nom
        prenom
        dateDeNaissance
      }
      ... on PersonneMorale {
        siret
        siegeSocial
        naf
        libelleNaf
        address {
          label
          streetNumber
          streetName
          postalCode
          cityName
          cityCode
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
      }
    }

    messages {
      email
      body
      createdAt
      attachments { url filename }
    }

    avis {
      question
      reponse
      questionLabel
      questionAnswer
      dateQuestion
      dateReponse
      expert { email }
    }

    champs { ...ChampFragment }
    annotations { ...ChampFragment }
  }
}

fragment ChampFragment on Champ {
  __typename
  id
  champDescriptorId
  label
  stringValue
  updatedAt

  ... on PieceJustificativeChamp {
    files { url filename contentType byteSizeBigInt }
  }
  ... on SiretChamp {
    etablissement {
      siret
      address { label postalCode cityName }
      entreprise { siren raisonSociale formeJuridique }
    }
  }
  ... on CarteChamp {
    geoAreas {
      source
      description
      geometry { type coordinates }
    }
  }
  ... on RepetitionChamp {
    rows {
      id
      champs {
        id
        champDescriptorId
        label
        stringValue
      }
    }
  }
}
```

### Correspondance des attributs

| Attribut v1 | Équivalent v2 | Remarque |
|---|---|---|
| `id` | `number` | |
| `email` | `usager.email` | |
| `state` | `state` | Valeurs différentes, voir § 6 |
| `simplified_state` | — | Libellé français ; à reconstituer côté client (§ 6) |
| `created_at` | — | **Pas d’équivalent exact** ; utiliser `dateDepot` |
| `updated_at` | `dateDerniereModification` | |
| `initiated_at` | `dateDepot` | |
| `received_at` | `datePassageEnInstruction` | |
| `processed_at` | `dateTraitement` | |
| `archived` | `archived` | |
| `motivation` | `motivation` | |
| `justificatif_motivation` | `motivationAttachment.url` | |
| `attestation` | `attestation.url` | |
| `instructeurs` | `instructeurs { email }` | v1 : tableau de courriels ; v2 : objets |
| `individual` | `demandeur` sur `... on PersonnePhysique` | |
| `entreprise` | `demandeur` sur `... on PersonneMorale { entreprise }` | |
| `etablissement` | `demandeur` sur `... on PersonneMorale` | |
| `commentaires` | `messages` | Renommé |
| `avis` | `avis` | |
| `champs` | `champs` | |
| `champs_private` | `annotations` | Renommé |
| `cerfa` | — | Valait toujours `[]` en v1 |
| `pieces_justificatives` | — | Pièces justificatives historiques, supprimées |
| `types_de_piece_justificative` | — | Idem |

### 5.1 Demandeur : `individual` / `etablissement` → `demandeur`

En v1, un dossier exposait `individual` **et** `etablissement` **et**
`entreprise`, dont deux étaient toujours `null`. En v2, un seul champ
`demandeur` renvoie soit une `PersonnePhysique`, soit une `PersonneMorale` ;
on discrimine avec `__typename` et des fragments.

| v1 `individual` | v2 `PersonnePhysique` |
|---|---|
| `civilite` | `civilite` |
| `nom` | `nom` |
| `prenom` | `prenom` |
| `date_naissance` | `dateDeNaissance` |

| v1 `etablissement` | v2 `PersonneMorale` |
|---|---|
| `siret` | `siret` |
| `siege_social` | `siegeSocial` |
| `naf` | `naf` |
| `libelle_naf` | `libelleNaf` |
| `adresse` | `address.label` |
| `numero_voie` | `address.streetNumber` |
| `type_voie` | `address.streetAddress` |
| `nom_voie` | `address.streetName` |
| `complement_adresse` | `address` (objet complet) |
| `code_postal` | `address.postalCode` |
| `localite` | `address.cityName` |
| `code_insee_localite` | `address.cityCode` |

> Les champs plats (`adresse`, `codePostal`, `localite`…) existent encore sur
> `PersonneMorale` mais sont **dépréciés** au profit de l’objet `address`.
> Utilisez `address` pour tout nouveau code.

Les attributs de `entreprise` (v1) se retrouvent à l’identique sous
`PersonneMorale.entreprise`, à deux exceptions près : `effectif_mois`,
`effectif_annee`, `effectif_mensuel`, `effectif_annuel` et
`effectif_annuel_annee` sont regroupés dans `effectifMensuel { periode nb }` et
`effectifAnnuel { periode nb }`.

### 5.2 Commentaires → messages

| v1 `commentaires` | v2 `messages` |
|---|---|
| `email` | `email` |
| `body` | `body` |
| `created_at` | `createdAt` |
| `attachment` | `attachments { url }` | 
| `piece_jointe_attachments` | `attachments` |

La v1 ne renvoyait qu’une seule pièce jointe (`attachment`) ; la v2 renvoie la
liste complète.

### 5.3 Avis

| v1 | v2 |
|---|---|
| `introduction` | `question` |
| `answer` | `reponse` |
| `question_label` | `questionLabel` |
| `question_answer` | `questionAnswer` |
| `created_at` | `dateQuestion` |
| `answered_at` | `dateReponse` |
| — | `expert { email }`, `claimant { email }`, `attachments` (nouveaux) |

---

## 6. Correspondance des états

La v1 exposait des états historiques en anglais. La v2 utilise les états
internes, en français.

| v1 `state` | v2 `state` | v1 `simplified_state` |
|---|---|---|
| `initiated` | `en_construction` | En construction |
| `received` | `en_instruction` | En instruction |
| `closed` | `accepte` | Accepté |
| `refused` | `refuse` | Refusé |
| `without_continuation` | `sans_suite` | Classé sans suite |

`simplified_state` n’a pas d’équivalent : c’était un libellé d’affichage
français. Reconstituez-le côté client à partir du tableau ci-dessus.

> Les dossiers en `brouillon` ne sont exposés **ni** par la v1 **ni** par la v2.

---

## 7. Valeurs des champs : attention aux différences

`stringValue` (v2) **n’est pas toujours identique** à `value` (v1). La v1
renvoyait la valeur brute stockée, la v2 renvoie une valeur formatée. Les écarts
à vérifier :

| Type de champ | v1 `value` | v2 `stringValue` |
|---|---|---|
| Case à cocher, oui/non | Valeur brute stockée | `"true"` / `"false"` |
| Nombre entier, nombre décimal | Valeur formatée | Valeur brute |
| Liste à deux niveaux | Objet `{ primary, secondary }` | Chaîne unique |
| Pièce justificative | URL du fichier (un seul) | `null` → utiliser `files { url }` |
| Carte | `null` | `null` → utiliser `geoAreas` |
| Département | Tiret long (`–`) possible | Tiret court (`-`) normalisé |
| Titre d’identité | Jamais d’URL | Jamais d’URL (inchangé) |

Trois cas demandent une réécriture, pas une simple transposition :

- **Pièces justificatives** : la v1 ne gérait qu’un fichier par champ. La v2
  renvoie `files`, un tableau — un même champ peut contenir plusieurs fichiers.
- **Listes à deux niveaux** : parsez `stringValue` ou lisez les deux valeurs
  séparément, l’objet `{ primary, secondary }` n’existe plus.
- **Blocs répétables** : la v1 exposait `rows` avec un `id` séquentiel (1, 2,
  3…). La v2 expose `rows { id champs }` avec un identifiant opaque. Si vous
  vous appuyiez sur l’ordre numérique, utilisez l’ordre du tableau.

---

## 8. Ce qui n’a aucun équivalent en v2

À vérifier avant de basculer :

| Donnée v1 | Statut |
|---|---|
| `procedure.total_dossier` | Aucun compteur en v2. Il faut paginer et compter, ou suivre le total de votre côté. |
| `procedure.direction` | Valait toujours `""`. |
| `procedure.geographic_information` | Module cartographique historique, retiré. |
| `procedure.types_de_piece_justificative` | Pièces justificatives d’avant 2016, retirées. |
| `dossier.cerfa` | Valait toujours `[]`. |
| `dossier.pieces_justificatives` | Idem `types_de_piece_justificative`. |
| `dossier.created_at` | La v2 n’expose pas la date de création du brouillon ; utilisez `dateDepot`. |
| `dossier.simplified_state` | Libellé d’affichage, à reconstituer (§ 6). |
| `service.email` / `phone` / `schedule` / `address` | Non exposés par la v2. |
| Jeton en paramètre d’URL (`?token=`) | Supprimé, en-tête `Authorization` obligatoire. |

---

## 9. Gestion des erreurs

La v1 signalait les erreurs par le code HTTP. En GraphQL, une requête bien
formée renvoie **toujours `200`** ; les erreurs sont dans le corps.

| Situation | v1 | v2 |
|---|---|---|
| Jeton absent ou invalide | `401` | **`403`** |
| Jeton expiré | `401` | `401` |
| Réseau non autorisé | `403` | `403` |
| Démarche/dossier inexistant ou non autorisé | `404` | `200` + `errors[].message` |

> Attention : un jeton absent ou invalide renvoie **`403`** en v2, là où la v1
> renvoyait `401`. Seul un jeton *expiré* donne un `401`. Si votre code teste
> `if status == 401` pour déclencher un renouvellement, il faut l’adapter.

Même en cas d’erreur HTTP, le corps de la réponse garde la forme GraphQL
(`errors` + `data: null`), avec un code applicatif dans `extensions.code` :

```json
{
  "errors": [
    {
      "message": "Token expired",
      "extensions": { "code": "unauthorized" }
    }
  ],
  "data": null
}
```

Vérifiez donc systématiquement la présence de la clé `errors` :

```json
{
  "data": { "demarche": null },
  "errors": [
    { "message": "Demarche not found", "path": ["demarche"] }
  ]
}
```

---

## 10. Explorer le schéma

L’API v2 est auto-documentée. Trois points d’entrée :

- **Documentation de référence** :
  <https://doc.demarche.numerique.gouv.fr/api-graphql> — guide d’utilisation de
  l’API GraphQL, exemples et cas d’usage.
- **Playground interactif** :
  <https://www.demarches-simplifiees.fr/graphql> (connecté comme administrateur)
  — complétion automatique et documentation intégrée.
- **Schéma complet** :
  <https://www.demarches-simplifiees.fr/graphql/schema>.

Le schéma fait autorité : si ce document et le schéma divergent, c’est le
schéma qui est à jour.

---

## 11. Aide

En cas de blocage, contactez le support en précisant :

- le ou les endpoints v1 que vous utilisiez ;
- les attributs dont vous dépendez (surtout ceux listés au § 8) ;
- le numéro de la démarche concernée.
