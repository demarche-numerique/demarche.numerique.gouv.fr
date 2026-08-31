# frozen_string_literal: true

module Emails
  # Slugs used in the admin URLs before the rename, read by the redirects of
  # config/routes/administrateur.rb.
  LEGACY_SLUGS = {
    "initiated_mail" => "depose",
    "received_mail" => "passe_en_instruction",
    "closed_mail" => "accepte",
    "refused_mail" => "refuse",
    "without_continuation" => "classe_sans_suite",
    "re_instructed_mail" => "repasse_en_instruction",
  }.freeze

  # The scope of the edition form, shared by every type: the param key of a
  # subclass would change under the admin whenever the type does.
  PARAM_KEY = :email_template

  # Param key posted by an editor rendered before the form scope was unified,
  # keyed by slug. Read by EmailTemplatesController, so the save of an editor
  # left open across the deploy still lands. It cannot be derived from the
  # record: the depose subclasses share a slug, not a param key.
  # TODO: remove once the deploy is out, with LEGACY_SLUGS and the redirects.
  LEGACY_PARAM_KEYS = {
    "depose" => "emails_depose",
    "passe_en_instruction" => "emails_passe_en_instruction",
    "accepte" => "emails_accepte",
    "refuse" => "emails_refuse",
    "classe_sans_suite" => "emails_classe_sans_suite",
    "repasse_en_instruction" => "emails_repasse_en_instruction",
  }.freeze
end
