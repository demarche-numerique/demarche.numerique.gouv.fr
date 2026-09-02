# frozen_string_literal: true

require 'open3'

# Renders a Typst template from lib/typst/ into an accessible (PDF/UA-1) PDF
# with the typst CLI: the JSON payload is written to a tempfile under the
# compilation root (a large form serialized into argv would overflow the
# kernel's per-argument limit, and argv is visible in the host process list)
# and the PDF comes back on stdout. The compilation root is the Rails root,
# so templates and payloads reference repo files (fonts, app/assets/images
# logos) directly.
#
# Typst renders payload strings as literal text, never as markup.
class TypstService
  class Error < StandardError; end

  TEMPLATES_DIR = Rails.root.join('lib/typst')
  FONTS_DIR = Rails.root.join('lib/prawn/fonts')
  # Root-relative path of the query helpers, imported into every expression.
  INTROSPECTION_HELPERS = '/lib/typst/introspection.typ'

  def self.generate_pdf(template, data)
    run('compile', '--pdf-standard', 'ua-1', template_path(template), '-', data:, binmode: true, failure: 'PDF generation')
  end

  # Introspects the laid-out document instead of parsing the PDF: evaluates a
  # Typst expression in the context of the rendered template (typst eval --in)
  # and returns its JSON-decoded value. The helpers of
  # lib/typst/introspection.typ (headings(), links(), lists(), enums(),
  # tables(), paragraphs(), plain()) are in scope. Used by specs to assert
  # document content.
  def self.query(template, data, expression)
    code = "{\n  import \"#{INTROSPECTION_HELPERS}\": *\n  #{expression}\n}"
    JSON.parse(run('eval', '--in', template_path(template), code, data:, failure: 'document query'))
  end

  # Letterhead of every document (theme.typ `letterhead`): the instance's
  # bloc-marque and logotype, resolved to compilation-root paths, and the
  # sender lines of the footer. Both images are ENV-configurable (LOGO_SRC,
  # LOGO_MARIANNE_SRC); an empty LOGO_MARIANNE_SRC omits the bloc-marque and
  # the logotype takes its place.
  def self.letterhead
    {
      marianne: LOGO_MARIANNE_SRC.present? ? { path: asset_path(LOGO_MARIANNE_SRC), alt: 'Logo Marianne, République Française' } : nil,
      logo: { path: asset_path(LOGO_SRC), alt: APPLICATION_NAME },
      sender: [DIRECTION_LABEL.presence, APPLICATION_NAME].compact,
    }
  end

  # Root-relative path of an image, resolved across the asset load paths like
  # the web layouts do; nil when the file is missing or outside the
  # compilation root (the Rails root), in which case the theme renders the
  # alt text in a placeholder frame instead of failing the generation.
  def self.asset_path(src)
    file = Rails.application.config.assets.paths
      .map { Pathname(it.to_s).join(src) }
      .find(&:file?)
    return if file.nil? || !file.to_s.start_with?("#{Rails.root}/")

    "/#{file.relative_path_from(Rails.root)}"
  end

  def self.template_path(template) = TEMPLATES_DIR.join("#{template}.typ").to_s

  def self.run(command, *args, data:, failure:, binmode: false)
    Tempfile.create(['typst-payload', '.json'], Rails.root.join('tmp')) do |file|
      file.binmode
      file.write(JSON.generate(data))
      file.flush

      output, diagnostics, status = Open3.capture3(
        'typst', command,
        '--root', Rails.root.to_s,
        '--font-path', FONTS_DIR.to_s,
        '--ignore-system-fonts',
        # Root-relative path of the payload, read by the template with json().
        '--input', "data=#{file.path.delete_prefix(Rails.root.to_s)}",
        *args,
        binmode:
      )
      raise Error, "#{failure} failed: #{diagnostics}" unless status.success?

      output
    end
  rescue SystemCallError => e
    # Host-level failures (missing or non-executable typst binary, unwritable
    # tmp/...): surface them under the service's own error class so callers
    # have a single failure contract to handle.
    raise Error, "#{failure} failed: #{e.message}"
  end

  private_class_method :template_path, :run
end
