export default {
  introspection: {
    type: 'sdl',
    paths: ['app/graphql/schema.graphql']
  },
  website: {
    template: 'carbon-multi-page',
    output: './public/graphql/schema',
    options: {
      appTitle: "Schema de l’API GraphQL de demarches-simplifiees.fr",
      appLogo: 'https://www.demarches-simplifiees.fr/logo-icon.png',
      siteRoot: '/graphql/schema',
      queryGenerationFactories: {
        ISO8601DateTime: new Date().toISOString(),
        ISO8601Date: new Date().toISOString(),
        BigInt: BigInt(Number.MAX_SAFE_INTEGER).toString()
      },
      externalLinks: [
        {
          href: 'https://www.demarches-simplifiees.fr',
          label: 'demarches-simplifiees.fr',
          position: 'header'
        },
        {
          href: 'https://github.com/demarches-simplifiees/demarches-simplifiees.fr',
          label: 'GitHub',
          position: 'header',
          kind: 'Github'
        }
      ],
      pages: [
        {
          title: 'Introduction',
          content: [
            {
              title: 'Welcome',
              content: `# Schema de l’API GraphQL de demarches-simplifiees.fr

L'API v2 suit le paradigme GraphQL. Si GraphQL est un lointain sujet pour vous, nous vous recommandons de prendre le temps de consulter les liens suivants :

* [Introduction aux concepts et raisons d’être de GraphQL](https://blog.octo.com/graphql-et-pourquoi-faire/) (en français)
* [Documentation officielle de la spécification GraphQL](https://graphql.org/) (en anglais)

## Point d’entrée et Schema GraphQL

* https://www.demarches-simplifiees.fr/api/v2/graphql
* Éditeur de requêtes en ligne : [https://www.demarches-simplifiees.fr/graphql](https://www.demarches-simplifiees.fr/graphql)
* [Schema GraphQL](https://github.com/demarches-simplifiees/demarches-simplifiees.fr/blob/main/app/graphql/schema.graphql)
`
            }
          ]
        }
      ]
    }
  }
};
