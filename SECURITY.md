# Politiques et procédures de sécurité

Ce document décrit les procédures de sécurité et les politiques générales pour le projet 'demarches-simplifiees.fr'.

  * [Signaler une faille](#signaler-une-faille)
  * [Politique de divulgation](#politique-de-divulgation)
  * [Commentaires sur cette politique](#commentaires-sur-cette-politique)

## Signaler une faille

La communauté et l’équipe cœur de 'demarches-simplifiees.fr' prennent au très au sérieux la sécurité de l’application.
Signalez toute faille de sécurité en envoyant un mail à l’équipe cœur tech@demarches-simplifiees.fr

Si la faille vous paraît critique, vous pouvez utiliser la clée gpg suivante pour chiffrer votre alerte :

```
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
6Be9Gt2A9DpK4ne1JshyiBo/zkw=
=/exZ
-----END PGP PUBLIC KEY BLOCK---
```

ex: `gpg --encrypt --recipient-file "fichier_avec_la_clé_publique" --output "fichier_chiffré" "fichier_en_clair"`

L’équipe accusera réception de votre mail dans les 72 heures. Après la réponse initiale à votre rapport, elle vous tiendra informé de la progression vers une correction et une annonce complète, et pourra vous demander des informations ou des conseils supplémentaires.

## Politique de divulgation et de correction

Lorsque l’équipe reçoit un rapport sur une faille de sécurité, elle procède aux étapes suivantes :

  * Confirmer le problème et déterminer les versions affectées.
  * Vérifier le code pour trouver tout problème similaire potentiel.
  * Communiquer par mattermost aux différentes instances connues qu’une faille est en cours de résolution
  * Préparer les correctifs, les merger sur la branche production et les déployer sur l’instance DINUM
  * Communiquer par mattermost aux différentes instances connues que le correctif est disponible sur la branche principale

## Commentaires sur cette politique

Si vous avez des suggestions sur la façon dont ce processus pourrait être amélioré, veuillez soumettre une demande de téléchargement.
