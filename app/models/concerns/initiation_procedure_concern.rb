# frozen_string_literal: true

module InitiationProcedureConcern
  extend ActiveSupport::Concern

  class_methods do
    def create_initiation_procedure(administrateur)
      p = Procedure.new(
        libelle: 'Une première procédure',
        description: "Une première procédure afin de découvrir les possibilités de #{Current.application_name}",
        organisation: 'Dinum',
        cadre_juridique: "inexistant car c’est un test",
        duree_conservation_dossiers_dans_ds: 1,
        for_individual: true,
        administrateurs: [administrateur]
      )

      p.draft_revision = p.revisions.build

      p.save!

      p.draft_revision.add_type_de_champ({ type_champ: :text, libelle: 'nouveau champ' })
      p.defaut_groupe_instructeur.instructeurs << administrateur.instructeur

      service = Service.create(
        nom: 'Un très bon service',
        organisme: "d’un excellent organisme",
        type_organisme: Service.type_organismes.fetch(:autre),
        email: 'contactez@moi.fr',
        telephone: '1234',
        horaires: 'de 9 h à 18 h',
        adresse: 'adresse',
        siret: Service::SIRET_TEST,
        etablissement_infos: { adresse: "75 rue du Louvre\n75002\nPARIS\nFRANCE" },
        etablissement_lat: 48.87,
        etablissement_lng: 2.34,
        administrateur:
      )

      p.update(service:)

      p
    end
  end
end
