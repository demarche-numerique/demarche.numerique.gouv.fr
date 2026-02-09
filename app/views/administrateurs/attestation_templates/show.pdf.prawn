# frozen_string_literal: true

require 'prawn/measurement_extensions'

#----- A4 page size
page_size = 'A4'
# page_height = 842
page_width = 595

#----- margins
body_width = 400
top_margin = 50
bottom_margin = 20
footer_height = top_margin - bottom_margin

right_margin = (page_width - body_width) / 2
left_margin = right_margin

#----- size of images
max_logo_width = body_width
max_logo_height = 50.mm
max_signature_size = 50.mm

def normalize_pdf_text(text)
  strip_tags(text&.tr("\t", '  '))
end

title = normalize_pdf_text(@attestation.fetch(:title))
body = normalize_pdf_text(@attestation.fetch(:body))
footer = normalize_pdf_text(@attestation.fetch(:footer))
created_at = @attestation.fetch(:created_at)

logo = @attestation[:logo]
signature = @attestation[:signature]

def download_file_and_retry(file_or_attached_one, max_attempts = 3)
  if file_or_attached_one.is_a?(ActiveStorage::Attached::One)
    file_or_attached_one.download
  else
    file_or_attached_one.rewind && file_or_attached_one.read
  end
rescue Fog::OpenStack::Storage::NotFound => e
  if max_attempts > 0
    max_attempts = max_attempts - 1
    sleep 1
    retry
  else
    raise e
  end
end

prawn_document(margin: [top_margin, right_margin, bottom_margin, left_margin], page_size: page_size) do |pdf|
  pdf.font_families.update('marianne' => { normal: Rails.root.join('lib/prawn/fonts/marianne/marianne-regular.ttf') })
  pdf.font 'marianne'
  pdf.fallback_fonts = ['Helvetica']

  grey = '555555'
  black = '333333'

  body_height = pdf.cursor - footer_height

  pdf.bounding_box([0, pdf.cursor], width: body_width, height: body_height) do
    if logo.present?
      logo_content = if logo.is_a?(ActiveStorage::Attached::One)
        logo.download
      else
        logo.rewind && logo.read
      end
      pdf.image StringIO.new(logo_content), fit: [max_logo_width, max_logo_height], position: :center
    end

    pdf.fill_color grey
    pdf.pad_top(40) { pdf.text "le #{DateFormatHelper.long(created_at)}", size: 9, align: :right, character_spacing: -0.5 }

    pdf.fill_color black
    pdf.pad_top(40) { pdf.text title, size: 14, character_spacing: -0.2 }

    pdf.fill_color grey
    pdf.pad_top(30) { pdf.text body, size: 9, character_spacing: -0.2, align: :justify }

    if signature.present?
      pdf.pad_top(40) do
        signature_content = if signature.is_a?(ActiveStorage::Attached::One)
          signature.download
        else
          signature.rewind && signature.read
        end
        pdf.image StringIO.new(signature_content), fit: [max_signature_size, max_signature_size], position: :right
      end
    end
  end

  pdf.repeat(:all) do
    pdf.move_cursor_to footer_height - 10
    pdf.fill_color grey
    if footer.present?
      # We reduce the size of large footer so they can be drawn in the corresponding area.
      # This is due to a font change, the replacing font is slightly bigger than the previous one
      footer_font_size = footer.length > 170 ? 7 : 8
      pdf.text footer, align: :center, size: footer_font_size
    end
  end
end
