# frozen_string_literal: true

# What a Typst template of lib/typst/root renders: already-localized strings
# and resolved image paths, never markup (Typst inserts payload strings as
# literal text). A payload class is named after its template
# (Typst::AttestationDepotPayload renders attestation_depot.typ) and builds
# the JSON-serializable hash in #build; #to_h sanitizes its strings and
# TypstService.render does the rest.
class Typst::Payload
  # Word pastes its bullets as Symbol and Wingdings codes in the private use
  # area (U+F0xx = the font's byte): the characters they stood for, which the
  # theme fonts or typst's embedded fallbacks display.
  PRIVATE_USE_SYMBOLS = {
    "\uF0B7" => '•', # Symbol bullet, Word's default
    "\uF09F" => '•',
    "\uF0A3" => '•',
    "\uF0A7" => '▪', # Wingdings small square, Word's second-level bullet
    "\uF0A8" => '▪',
    "\uF06E" => '■',
    "\uF06F" => '□',
    "\uF071" => '❑',
    "\uF072" => '❑',
    "\uF076" => '❖',
    "\uF07F" => '▫',
    "\uF0D8" => '➢', # Wingdings arrow bullet
    "\uF0E0" => '⇨',
    "\uF0E8" => '⇨',
    "\uF0F0" => '⇨',
    "\uF0FC" => '✔', # Wingdings check bullet
    "\uF0FE" => '☑',
    "\uF0FD" => '☒',
    "\uF028" => '☎',
    "\uF02A" => '✉',
    # look-alikes of characters the fonts display, typed from other layouts
    "\u2E31" => '·', # word separator middle dot
    "\uA78F" => '·', # letter sinological dot
    "\uFFEB" => '→', # halfwidth rightwards arrow
  }.freeze

  # Characters no available font displays, which typst then refuses to
  # compile under --pdf-standard ua-1, or PDF/UA forbids outright (U+FEFF).
  # The theme fonts and typst's embedded fallbacks cover letters, punctuation
  # and common symbols (✔, ☐, →, ★…), not emoji nor the private use area.
  UNDISPLAYABLE = /
    [\u0000-\u0008\u000B-\u001F\u007F-\u009F]                          # control characters (the tab is turned into a space first)
    | [\u200B-\u200D\u2060\uFEFF]                                     # zero-width characters, word joiner, byte order mark
    | [\uFE00-\uFE0F\u20E3\u{E0000}-\u{E01EF}]                        # variation selectors, keycap, tags
    | \p{Emoji_Presentation} | \p{Emoji_Modifier} | [\u{1F000}-\u{1FAFF}] # emoji, skin tones, pictographs, flags, enclosed letters
    | [\uE000-\uF8FF\u{F0000}-\u{10FFFD}]                              # private use area (after PRIVATE_USE_SYMBOLS)
  /x

  def self.template = name.demodulize.delete_suffix('Payload').underscore

  # A deep copy of a payload value whose every string is displayable:
  # hashes and arrays are walked, numbers, booleans and nil pass through.
  def self.sanitize(value)
    case value
    when String then sanitize_text(value)
    when Hash then value.transform_values { sanitize(it) }
    when Array then value.map { sanitize(it) }
    else value
    end
  end

  def self.sanitize_text(text)
    text.tr("\t", ' ').gsub(Regexp.union(PRIVATE_USE_SYMBOLS.keys), PRIVATE_USE_SYMBOLS).gsub(UNDISPLAYABLE, '')
  end

  def template = self.class.template

  # The document data, every string sanitized: the admin-authored text the
  # payloads carry (libellés, descriptions, options) is pasted from anywhere.
  def to_h = self.class.sanitize(build)

  def build
    raise NotImplementedError, "#{self.class} must build its payload in #build"
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
