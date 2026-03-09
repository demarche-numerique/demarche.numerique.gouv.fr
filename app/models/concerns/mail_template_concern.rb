# frozen_string_literal: true

module MailTemplateConcern
  extend ActiveSupport::Concern

  include TagsSubstitutionConcern

  module Actions
    SHOW         = :show
    ASK_QUESTION = :ask_question
    REPLY        = :reply
  end

  def subject_for_dossier(dossier)
    replace_tags(subject, dossier, escape: false).presence || replace_tags(self.class::DEFAULT_SUBJECT, dossier, escape: false)
  end

  def body_for_dossier(dossier)
    replace_tags(body, dossier)
  end

  def actions_for_dossier(dossier)
    [MailTemplateConcern::Actions::SHOW, MailTemplateConcern::Actions::ASK_QUESTION]
  end

  def attachment_for_dossier(dossier)
    nil
  end

  def update_rich_body
    self.rich_body = self.body
  end

  included do
    has_rich_text :rich_body
    before_save :update_rich_body
  end

  class_methods do
    def default_for_procedure(procedure)
      template_name = default_template_name_for_procedure(procedure)
      rich_body = ActionController::Base.render(template: template_name).gsub(/<!--.*?-->/m, '')
      trix_rich_body = rich_body.gsub(/(?<!^|[.-])(?<!<\/strong>)\n/, ' ')
      new(subject: const_get(:DEFAULT_SUBJECT), body: trix_rich_body, rich_body: trix_rich_body, procedure: procedure)
    end

    def default_template_name_for_procedure(procedure)
      const_get(:DEFAULT_TEMPLATE_NAME)
    end
  end

  def dossier_tags
    super + TagsSubstitutionConcern::DOSSIER_TAGS_FOR_MAIL
  end
end
