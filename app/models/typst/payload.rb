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
