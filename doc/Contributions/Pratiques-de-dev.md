# Bonnes pratiques de développement

## Branches du projet

- `main`, branche qui contient le code du site tel qu’il est [en intégration](https://dev.demarches-simplifiees.fr/)
- les [releases](https://github.com/demarches-simplifiees/demarches-simplifiees.fr/releases) pointent sur la branche `main` (historiquement sur la branche `production`)

## Cycle de développement

1. Pour chaque ensemble de modifications, créer une branche associée
  (sur le repo principal si vous avez les droits, sinon sur un fork personnel).
2. Une fois les modifications faites, créer une Pull Request sur GitHub.
3. Si un·e relectrice·eur ne s’est pas manifesté·e au bout de 48 h, relancer en mettant un message dans la PR.
4. Quand la Pull Request a été relue et validée :
    1. le contributeur rebase la branche par rapport à `main` (manuellement, ou en mettant un commentaire "/rebase" dans la PR),
    2. le mainteneur merge la PR.

## Pour une première contribution

Si c’est votre première contribution, commencez par une toute petite Pull Request (PR), par exemple de nettoyage,
pour vous faire la main sur le processus.

## Bonnes pratiques : sur le code

### Tests

- Le code doit être testé, la PR doit contenir les tests (toute PR sans test sera a priori rejetée).

### Code mort / code propre

- Une contribution ne devrait pas comporter de code mort (enlever le code commenté ou jamais appelé).

### Injection de dépendance

D'une manière générale, nous préférons avoir des controlleurs verbeux mais explicites.
Afin d’éviter de trop alourdir les contrôleurs et les modèles, déjà bien chargés, nous mettons parfois en place des services pour centraliser une partie cohérente des traitements (voir [DossierProjectionService](https://github.com/betagouv/demarches-simplifiees.fr/blob/92f463bc039200b98908dc5c09366844b0e1d593/app/services/dossier_projection_service.rb), [PieceJustificativeService](https://github.com/betagouv/demarches-simplifiees.fr/blob/92f463bc039200b98908dc5c09366844b0e1d593/app/services/pieces_justificatives_service.rb))

- Toute injection de dépendance doit être utilisée (sinon ne pas la coder)
- Il est demandé d’éviter l’injection de dépendance dans les constructeurs.
  (Une exception pourrait être prise en compte si deux implémentations différentes, hors tests, sont injectées.)
- On mock directement les dépendances concernées (parce que ruby, c’est magique)

```ruby
# Non
def initializer(http_service)
 @http_service = http_service
end

def get
  @http_service.get(url)
end

# Oui
def get
  Typhoeus.get(url)
end

# spec

expect(Service).to receive(:do_stuff).and_return(true)
## ou même
expect_any_instance_of(Procedure).to receive(:procedure_overview).and_return(procedure_overview)
```

### Utilisation de LLM

Les LLM sont autorisés comme aide à la génération de code. Cependant, garder en tête que **le développeur qui commit le code en reste le responsable**. Il convient donc, comme pour tout code de respecter l’ensemble des bonnes pratiques implicites (inéhrentes au métier de développeur) et mentionnées dans ce documents, notamment de :

- vous assurer que vous comprenez l’intégralité du code et ses implications ;
- le code est pertinent (y compris pour les tests) ;
- respecte les bonnes pratiques usuelles (ie. respecte les conventions de la codebase, pas de code ou duplication inutile…).
- s’assurer que le code est compatible avec [notre licence AGPL](/LICENSE.txt)

Autrement dit, le LLM n’est qu’un outil, et il convient d’être tout aussi fier et responsable du code généré que pour n’importe quel code que vous signez.

## Bonnes pratiques : sur les PR

- Toujours mettre un message décrivant l’objet de la PR
- Si la PR concerne des changements visuels, mettre une capture d’écran
- Faites de petites PR. Si la PR est trop grosse (> 400 lignes), découpez-la en plusieurs PR. Chaque petite PR doit
  essayer d’apporter de la valeur au client, d’apporter une petite fonctionnalité.
- Le relecteur d’une PR peut prendre la main (après l’avoir demandé) pour faire les modifs de formes
- Les modifications de formes non détectées automatiquement sont optionnelles
- Néanmoins, les commits de nettoyage sont autorisés au sein de ces petites PRs
- Les remarques sur l’amélioration du code ne concernant pas directement la PR sont optionnelles

En date du 2021-10-19, voici une PR servant d’exemple :

* [#6519 ETQ Super Admin je veux changer l’adresse électronique d’un instructeur](https://github.com/betagouv/demarches-simplifiees.fr/pull/6519)

## Bonnes pratiques : sur les branches

- Donner un nom descriptif à ses branches
- Faire une branche par "sujet", ne pas faire de branches trop lourdes

**Attention** : Ne **pas utiliser le bouton "Update branch"** de GitHub.

Ce bouton merge `main` dans la feature branch – ce qui casse l’historique semi-linéraire. (Nous, ce qu’on voudrait, c’est rebaser).
À la place, rebaser manuellement la feature-branch sur `main` (ou mettre un commentaire "/rebase" dans la PR).

## Bonnes pratiques : sur les commits

- Les messages de commit sont écrits en anglais
- Faire des petits commits, les plus unitaires possible, homogènes et en essayant de ne pas mélanger les sujets.
- Les commits correctifs sont à "fixup-er" dans les commits qu’ils corrigent
- Séparer les modifications relatives à du nettoyage dans un commit séparé, voire une PR séparée
- Dans le cas où un commit corrige un bug ou implémente une feature, mentionner dans le message de commit le numéro de l’issue avec `Closes #XXXX` ou `Ref #XXXX`

Exemple d’une série de commits :

- un commit pour du renommage,
- un commit pour un ajout de méthode + test,
- un commit pour l’interface utilisateur

### Signatures de commits

Des considérations de sécurité impliquent que les commits doivent être [(co-)signés](https://docs.github.com/fr/authentication/managing-commit-signature-verification/signing-commits) afin d’être incorporés dans `main`.

Pour les développeurs de la core-team:

- *tous* les commits doivent être signés
- la signature doit être faite avec une clé GPG exclusivement

Pour les contributeurs externes, une co-signature par un(e) membre de l’équipe lors de la relecture est suffisante.

> [!NOTE]
> Pour des raisons pratiques, la branche sera éventuellement amendée / push-forcée sur le fork du contributeur, ce qui implique d’accorder un droit en écriture sur ce fork au relecteur, ou de recréer une branche avec les commits signés, puis une nouvelle PR sur cette branche.
