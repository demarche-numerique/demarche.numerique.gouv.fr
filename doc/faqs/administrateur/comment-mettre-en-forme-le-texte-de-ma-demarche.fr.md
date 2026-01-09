---
category: "administrateur"
subcategory: "create_procedure"
slug: "comment-mettre-en-forme-le-texte-de-ma-demarche"
locale: "fr"
keywords: "mise en forme, HTML, balises, texte démarche, gras, italique, souligné"
title: "Comment mettre en forme le texte de ma démarche ?"
---

# Comment mettre en forme le texte de ma démarche ?

Il est possible de mettre en forme certaines parties de votre démarche en utilisant des balises HTML. Ces éléments de code vous permettent de :

- Mettre votre texte en *italique*
- <u>Souligner</u> votre texte
- Mettre votre texte en **gras**
- Faire un paragraphe
- Mettre votre texte sous forme de titre

## Quels sont les textes que je peux mettre en forme ?

Vous pouvez utiliser certaines balises HTML dans **les éléments de description générale** de votre démarche et dans **la description d’un champ** de votre démarche. Les balises ne sont pas reconnues dans le libellé de votre démarche et ne peuvent donc pas être mises en forme.

## Comment mettre en forme mon texte ?

Pour cela, utilisez les balises HTML, identifiées par les caractères `<` et `>`, avec une balise ouvrante (ex : `<p>`) et une balise fermante (ex : `</p>`). Notez que la balise fermante inclut une barre oblique `/` (slash) après le `<`.

### Exemples de mise en forme :

- **Mettre un texte en italique**
  - Balise ouvrante : `<em>`
  - Balise fermante : `</em>`
  - Exemple : « `Mon texte en <em>italique</em>` » affiche « Mon texte en *italique* »

- **Souligner un texte**
  - Balise ouvrante : `<u>`
  - Balise fermante : `</u>`
  - Exemple : `« Mon texte <u>souligné</u> »` affiche « Mon texte <u>souligné</u> »

- **Mettre un texte en gras**
  - Balise ouvrante : `<strong>`
  - Balise fermante : `</strong>`
  - Exemple : `« Mon texte en <strong>gras</strong> »` donne « Mon texte en **gras** »

- **Faire un paragraphe**
  - Balise ouvrante : `<p>`
  - Balise fermante : `</p>`
  - Exemple : `<p>Mon paragraphe</p>`.

 Généralement vous n’aurez pas besoin de créer un paragraphe, car un saut de ligne vide en créé toujours un nouveau.

## Aperçu du texte avec ces balises

Exemple dans la description de la démarche :

![Saisie de texte utilisant les balises b, i et u](faq/administrateur-example-markup.png)

Rendu côté usager :

![Aperçu de ce même texte faisant état d’une mise en gras, d’une mise en italique et d’un soulignement](faq/administrateur-example-markup-preview.png)
