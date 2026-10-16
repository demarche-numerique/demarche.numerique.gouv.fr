# frozen_string_literal: true

webhooks.create(
  :default,
  procedure: procedures.individual,
  url: "https://webhook.exemple.fr/endpoint",
  label: "Webhook de démonstration",
  event_types: ["dossier_depose", "dossier_accepte", "dossier_refuse"]
)
