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

  def self.generate_pdf(template, data)
    Tempfile.create(['typst-payload', '.json'], Rails.root.join('tmp')) do |file|
      file.binmode
      file.write(JSON.generate(data))
      file.flush

      pdf, diagnostics, status = Open3.capture3(
        'typst', 'compile',
        '--pdf-standard', 'ua-1',
        '--root', Rails.root.to_s,
        '--font-path', FONTS_DIR.to_s,
        '--ignore-system-fonts',
        # Root-relative path of the payload, read by the template with json().
        '--input', "data=#{file.path.delete_prefix(Rails.root.to_s)}",
        TEMPLATES_DIR.join("#{template}.typ").to_s,
        '-',
        binmode: true
      )
      raise Error, "PDF generation failed: #{diagnostics}" unless status.success?

      pdf
    end
  rescue Errno::ENOENT => e
    # Missing typst binary on the host: surface it under the service's own
    # error class so callers have a single failure contract to handle.
    raise Error, "PDF generation failed: #{e.message}"
  end
end
