# frozen_string_literal: true

# What a Typst template of lib/typst/root renders: already-localized strings
# and resolved image paths, never markup (Typst inserts payload strings as
# literal text). A payload class is named after its template
# (Typst::AttestationDepotPayload renders attestation_depot.typ) and builds
# the JSON-serializable hash in #to_h; TypstService.render does the rest.
class Typst::Payload
  def self.template = name.demodulize.delete_suffix('Payload').underscore

  def template = self.class.template

  def to_h
    raise NotImplementedError, "#{self.class} must build its payload in #to_h"
  end

  # Letterhead of every document (theme.typ `letterhead`): the instance's
  # bloc-marque and logotype, resolved to compilation-root paths, and the
  # sender lines of the footer. Both images are ENV-configurable (LOGO_SRC,
  # LOGO_MARIANNE_SRC); an empty LOGO_MARIANNE_SRC omits the bloc-marque and
  # the logotype takes its place.
  def letterhead
    {
      marianne: LOGO_MARIANNE_SRC.present? ? { path: asset_path(LOGO_MARIANNE_SRC), alt: 'Logo Marianne, République Française' } : nil,
      logo: { path: asset_path(LOGO_SRC), alt: APPLICATION_NAME },
      sender: [DIRECTION_LABEL.presence, APPLICATION_NAME].compact,
    }
  end

  private

  # Root-relative path of an image of lib/typst/root/images (the only images
  # a document can embed; the default logos ship there, an instance with its
  # own logos copies them alongside). nil when the file is missing or points
  # outside that directory, in which case the theme renders the alt text in
  # a placeholder frame instead of failing the generation.
  def asset_path(src)
    file = TypstService::IMAGES_DIR.join(src).expand_path
    return if !file.file? || !file.to_s.start_with?("#{TypstService::IMAGES_DIR}/")

    "/#{file.relative_path_from(TypstService::ROOT)}"
  end
end
