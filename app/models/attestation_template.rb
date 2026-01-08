# frozen_string_literal: true

class AttestationTemplate < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  include TagsSubstitutionConcern

  belongs_to :procedure

  has_one_attached :logo
  has_one_attached :signature

  enum :state, {
    draft: 'draft',
    published: 'published',
  }

  enum :kind, {
    acceptation: 'acceptation',
    refus: 'refus',
  }

  validates :title, tags: true, if: -> { procedure.present? && version == 1 }
  validates :body, tags: true, if: -> { procedure.present? && version == 1 }
  validates :json_body, tags: true, if: -> { procedure.present? && version == 2 }
  validates :footer, length: { maximum: 190 }
  validates :kind, presence: true

  FILE_MAX_SIZE = 1.megabyte
  validates :logo, content_type: ['image/png', 'image/jpg', 'image/jpeg'], size: { less_than: FILE_MAX_SIZE }
  validates :signature, content_type: ['image/png', 'image/jpg', 'image/jpeg'], size: { less_than: FILE_MAX_SIZE }

  DOSSIER_STATE = Dossier.states.fetch(:accepte)

  scope :v1, -> { where(version: 1) }
  scope :v2, -> { where(version: 2) }

  TIPTAP_BODY_DEFAULT = {
    "type" => "doc",
    "content" => [
      {
        "type" => "header",
        "content" => [
          {
            "type" => "headerColumn",
                      "content" => [
                        {
                          "type" => "paragraph",
                          "attrs" => { "textAlign" => "left" },
                          "content" => [{ "type" => "mention", "attrs" => { "id" => "dossier_service_name", "label" => "nom du service" } }],
                        },
                      ],
          },
          {
            "type" => "headerColumn",
            "content" => [
              {
                "type" => "paragraph",
                          "attrs" => { "textAlign" => "left" },
                          "content" => [
                            { "text" => "Fait le ", "type" => "text" },
                            { "type" => "mention", "attrs" => { "id" => "dossier_processed_at", "label" => "date de décision" } },
                          ],
              },
            ],
          },
        ],
      },
      { "type" => "title", "attrs" => { "textAlign" => "center" }, "content" => [{ "text" => "Titre de l’attestation", "type" => "text" }] },
      {
        "type" => "paragraph",
        "attrs" => { "textAlign" => "left" },
        "content" => [
          {
            "text" => "Vous pouvez éditer ce texte pour personnaliser votre attestation. Pour ajouter du contenu issu du dossier, utilisez les balises situées sous cette zone de saisie.",
            "type" => "text",
          },
        ],
      },
    ],
  }.freeze

  def generate_attestation_for(dossier)
    return if dossier.attestation.present?

    pdf_data = build_pdf(dossier)

    attestation = Attestation.new(dossier:)
    attestation.title = replace_tags(title, dossier, escape: false) if version == 1
    attestation.pdf.attach(
      io: StringIO.new(pdf_data),
      filename: "attestation-dossier-#{dossier.id}.pdf",
      content_type: 'application/pdf',
      # we don't want to run virus scanner on this file
      metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
    )
    attestation.save!
  end

  def unspecified_champs_for_dossier(dossier)
    types_de_champ_by_tag_id = dossier.revision.types_de_champ.index_by { "tdc#{_1.stable_id}" }

    used_tags.filter_map do |used_tag|
      corresponding_type_de_champ = types_de_champ_by_tag_id[used_tag]

      if corresponding_type_de_champ && dossier.project_champ(corresponding_type_de_champ).blank?
        corresponding_type_de_champ
      end
    end
  end

  def dup
    attestation_template = super
    ClonePiecesJustificativesService.clone_attachments(self, attestation_template)
    attestation_template
  end

  def logo_url
    if logo.attached?
      logo_variant = logo.variant(resize_to_limit: [400, 400])
      logo_variant.key.present? ? logo_variant.processed.url : Rails.application.routes.url_helpers.url_for(logo)
    end
  end

  def render_attributes_for(params = {})
    groupe_instructeur = params[:groupe_instructeur]
    groupe_instructeur ||= params[:dossier]&.groupe_instructeur

    base_attributes = {
      created_at: Time.current,
      footer: params.fetch(:footer, footer),
      signature: signature_to_render(groupe_instructeur),
    }

    if version == 2
      render_attributes_for_v2(params, base_attributes)
    else
      render_attributes_for_v1(params, base_attributes)
    end
  end

  def tiptap_body
    json_body&.to_json
  end

  def tiptap_body=(json)
    self.json_body = JSON.parse(json)
  end

  private

  def render_attributes_for_v1(params, base_attributes)
    attributes = base_attributes.merge(
      logo: params.fetch(:logo, logo.attached? ? logo : nil)
    )

    dossier = params[:dossier]

    if dossier.present?
      attributes.merge(
        title: replace_tags(title, dossier, escape: false),
        body: replace_tags(body, dossier, escape: false)
      )
    else
      attributes.merge(
        title: params.fetch(:title, title),
        body: params.fetch(:body, body)
      )
    end
  end

  def render_attributes_for_v2(params, base_attributes)
    dossier = params[:dossier]

    json = json_body&.deep_symbolize_keys
    tiptap = TiptapService.new

    if dossier.present?
      # 2x faster this way than with `replace_tags` which would reparse text
      used_tags = TiptapService.used_tags_and_libelle_for(json.deep_symbolize_keys)
      substitutions = tags_substitutions(used_tags, dossier, escape: false)
      body = tiptap.to_html(json, substitutions)

      attributes.merge(body:).merge(base_attributes)
    else
      attributes.merge(
        body: params.fetch(:body) { tiptap.to_html(json) }
      ).merge(base_attributes)
    end
  end

  def signature_to_render(groupe_instructeur)
    if groupe_instructeur&.signature&.attached?
      groupe_instructeur.signature
    else
      signature
    end
  end

  def used_tags
    if version == 2
      json = json_body&.deep_symbolize_keys
      TiptapService.used_tags_and_libelle_for(json.deep_symbolize_keys).map(&:first)
    else
      used_tags_for(title) + used_tags_for(body)
    end
  end

  def build_pdf(dossier)
    if version == 2
      build_v2_pdf(dossier)
    else
      build_v1_pdf(dossier)
    end
  end

  def build_v1_pdf(dossier)
    attestation = render_attributes_for(dossier: dossier)
    ApplicationController.render(
      template: 'administrateurs/attestation_templates/show',
      formats: :pdf,
      assigns: { attestation: attestation }
    )
  end

  def build_v2_pdf(dossier)
    attributes = render_attributes_for(dossier:)
    body = attributes.fetch(:body)
    signature = attributes.fetch(:signature)

    html = ApplicationController.render(
      template: '/administrateurs/attestation_template_v2s/show',
      formats: [:html],
      layout: 'attestation',
      assigns: { attestation_template: self, body:, signature: }
    )

    WeasyprintService.generate_pdf(html, { procedure_id: procedure.id, dossier_id: dossier.id })
  end
end
