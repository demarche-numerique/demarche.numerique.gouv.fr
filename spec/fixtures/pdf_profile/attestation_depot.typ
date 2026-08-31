#import "theme.typ": *
#show: conf.with(title: "Attestation", lang: "fr")

#first-header(
[
#bloc-marque[#profile-image(alt: "Logo Marianne, République Française", height: 20mm)]

#logo-site[#profile-image(alt: "demarche.numerique.gouv.fr", height: 15mm)]
],
[
#direction-block[
#direction-label[Direction interministérielle du numérique]

#direction-site[demarche.numerique.gouv.fr]
]
],
)

#depot-title[Attestation de dépôt]

#depot-procedure[Démarche de démonstration]

#depot-description[Ce document atteste que Jeanne DUPONT a déposé le 30 août 2026 un dossier sur la démarche « Démarche de démonstration ».]

#depot-section[
#heading(level: 2)[Identité du demandeur]

#key-value(
  ([Prénom], [Jeanne]),
  ([Nom], [DUPONT]),
  ([Adresse électronique], [usager\@exemple.fr]),
)
]

#depot-section[
#heading(level: 2)[Dossier]

#key-value(
  ([Numéro de dossier], [274]),
  ([Dossier déposé le], [30 août 2026]),
  ([État du dossier], [déposé, en attente d’examen par l’administration]),
)
]

#depot-section[
#heading(level: 2)[Service administratif]

#key-value(
  ([Service], [Service de démonstration, Organisme de démonstration]),
  ([Adresse postale], [20 avenue de Ségur, 75007 Paris]),
  ([Adresse électronique], [contact\@exemple.fr]),
  ([Téléphone], [0102030405]),
)
]

#signature[
#par[Fait le 31 août 2026,]

#par[La direction de demarche.numerique.gouv.fr]
]
