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
end
