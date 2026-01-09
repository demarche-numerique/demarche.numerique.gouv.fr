---
category: "administrateur"
subcategory: "procedure_test"
slug: "guide-de-bonnes-pratiques-pour-tester-une-demarche"
locale: "fr"
keywords: "test démarche, étapes test, dépôt dossier, instruction, fonctionnalités secondaires"
title: "Guide de bonnes pratiques pour tester une démarche"
---

# Guide de bonnes pratiques pour tester une démarche

Tester une démarche est nécessaire avant toute publication. En effet, il s’agit d’une étape essentielle pour déployer un formulaire de qualité, cela permet notamment de :

- corriger les erreurs de votre formulaire et de le transmettre à votre délégué à la protection des données
- vérifier que le processus d’instruction envisagé correspond à vos besoins ainsi que toutes les fonctionnalités associées (emails automatiques, attestations, annotations privées, etc…)
- préparer votre service et vos usagers à l’utilisation de %{application_name}.


## Déroulé du test

Le test d’une démarche se déroule en trois étapes :

1. le test de la partie usager (dépôt de dossiers)
2. le test de la partie instructeur (instruction du dossier)
3. le test des fonctionnalités secondaires

Vous pouvez faire tester la partie usager (étape 1) et instructeur (étape 2) par des collaborateurs. Cependant, nous vous recommandons fortement de les tester vous-même une première fois.

**Vous pouvez effectuer toutes les modifications que vous souhaitez sur votre démarche pendant cette phase de test.**

Bien évidemment, avant de tester la démarche, il faut l’avoir créé. Pour cela, vous pouvez vous aider de [notre guide de la dématérialisation réussie via %{application_name}](https://456404736-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2F-L7_aKvpAJdAIEfxHudA%2Fuploads%2FGJm7S7LVjHPKVlMCE36e%2FGuide%20des%20bonnes%20pratiques%20démarches-simplifiees.pdf?alt=media&token=228e63c7-a168-4656-9cda-3f53a10645c2). Vous pouvez également consulter la documentation [Comment créer une nouvelle démarche](https://doc.demarches-simplifiees.fr/tutoriels/tutoriel-administrateur)

## Étape 1 : Déposer un dossier de test côté usager

Vous devez commencer par cette étape afin de tester le parcours d’un usager pour déposer un dossier. De plus, sans dossier déposé, vous ne pourrez pas tester les fonctionnalités relatives à l’instruction.

1. Utilisez le bouton **« Tester la démarche »** (ou suivez le lien de la démarche), accessibles depuis votre interface administrateur. Toute personne ayant connaissance du lien pourra remplir des dossiers test sur votre démarche qui seront supprimés plus tard.
  ![Bouton Tester la démarche depuis la tableau de bord de la démarche {aria-hidden="true"}](faq/administrateur-procedure-test-button.png)
  ![Affichage du lien de test de la démarche {aria-hidden="true"}](faq/administrateur-procedure-test-link.png)

2. Commencez à remplir votre dossier en suivant le bouton **« Commencer la démarche »**.
  ![Page d’accueil usager de la démarche {aria-hidden="true"}](faq/administrateur-procedure-test-commencer.png)

3. Après avoir complété le dossier et éventuellement testé les fonctionnalités dédiées à l’interface usagers (invitation à compléter un dossier…), cliquez sur **« Déposer le dossier »** pour finaliser le dépôt et voir le message de confirmation de dépôt.
  ![Test de la démarche par l’usager {aria-hidden="true"}](faq/administrateur-procedure-test-usager.png)

Une fois votre dossier de test déposé, un message de confirmation de dépôt sera affiché :

![Message de confirmation de dépôt d’un dossier {aria-hidden="true"}](faq/administrateur-procedure-test-thanks.png)

N’hésitez pas à [transmettre le lien vers la démarche test à vos collègues](/faq/administrateur/faire-tester-une-demarche-par-un-collegue) afin qu’ils puissent la tester et vous transmettre leur retour. Gardez à l’esprit que **tous les dossiers déposés pendant le test seront supprimés** lorsque la démarche sera modifiée ou publiée.

## Étape 2 : Instruire le dossier de test

Vous avez déposé à l’étape précédente un premier dossier. Rendez-vous désormais dans la partie instructeur.

Passez à l’interface instructeur via le lien [%{application_base_url}/procedures](/procedures) ou en changeant de profil depuis le menu en haut à droite en cliquant sur votre adresse électronique.

![Menu pour passer instructeur {aria-hidden="true"}](faq/administrateur-profile-switch.png)

⚠️ **Vous devez être instructeur de la démarche pour accéder aux dossiers déposés**. Par défaut, en tant que créateur de la démarche (administrateur), vous êtes instructeur de celle-ci. Si vous ne testez pas vous-même cette partie, ajoutez votre collaborateur en tant qu’instructeur.

Vous arrivez alors sur l’interface instructeur. Il vous suffit de cliquer sur l’onglet **« En test »** puis suivez le lien de votre démarche avec un dossier **« à suivre »** .

![Page d’accueil instructeur de la démarche {aria-hidden="true"}](faq/administrateur-procedures-list.png)

Trouvez le dossier à suivre, puis testez l’instruction du dossier.

![Dossier à suivre {aria-hidden="true"}](faq/administrateur-test-instruction-dossiers-list.png)

Voici le tutoriel pour instruire un dossier en tant qu’instructeur : [Tutoriel Instructeur](https://doc.demarches-simplifiees.fr/tutoriels/tutoriel-instructeur)

## Étape 3 : Tester les fonctionnalités secondaires

Vous pourrez ici tester différents éléments secondaires :

- Demande d’**avis externe** (partie instruction) . Pour plus d’information, vous pouvez consulter [notre tutoriel expert invité](https://doc.demarches-simplifiees.fr/tutoriels/tutoriel-expert-invite)
- **Vérifiez les adresses électroniques** d’accusé de réception, de passage en instruction, d’acceptation, de refus et de classement sans suite (partie usager)
- Testez la **messagerie du dossier** en envoyant un message à l’usager. Si vous souhaitez anonymiser l’adresse électronique des instructeurs dans la messagerie, vous pouvez [nous contacter à l’adresse %{contact_email}](mailto:%{contact_email})
- Si l’**attestation automatique d’acceptation** et la partie annotations privées ont été paramétrées, vérifiez qu’il n’y a pas d’erreur

En cas d’erreur et/ou en fonction des retours de vos collègues suite à la phase de test, vous pouvez modifier la démarche depuis votre profil administrateur.

**⚠️ Attention, suite aux modifications, tous les dossiers seront supprimés.**


## Fin du test : Passage en production

Après avoir minutieusement testé votre démarche, il est temps de la rendre accessible à tous en la publiant.

1. **Accédez au tableau de bord administrateur** de votre démarche et cliquez sur le bouton **« Publier »** situé en haut à droite.
  ![Bouton Publier {aria-hidden="true"}](faq/administrateur-procedure-test-publish.png)

2. **Personnalisez le lien** du formulaire pour le diffuser plus facilement à vos usagers. Cette étape vous permet de simplifier l’accès à votre démarche.

3. **Indiquez le lien de diffusion** de votre démarche, comme le site internet de votre organisme, pour faciliter la communication auprès des usagers.

4. **Prenez connaissance des mentions RGPD** avant la publication pour assurer la conformité de votre démarche avec le **Règlement Général sur la Protection des Données**.

5. **Finalisez la publication** en cliquant sur le bouton **« Publier »** situé en bas de l’écran.

Félicitations, vous êtes désormais administrateur d’une démarche publiée sur %{application_name} !

⚠️ **N’oubliez pas de diffuser le lien** de votre démarche auprès de vos usagers, accessible depuis votre interface administrateur. Ce lien est différent du lien de la démarche test.
