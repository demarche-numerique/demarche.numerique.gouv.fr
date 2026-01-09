# frozen_string_literal: true

class WatermarkService
  POINTSIZE = 20
  KERNING = 1.2
  ANGLE = 45
  FILL_COLOR = "rgba(0,0,0,0.4)"

  attr_reader :text
  attr_reader :text_length

  def initialize(text = APPLICATION_NAME)
    @text = " #{text} " # give more space around each occurence
    @text_length = @text.length
  end

  def process(file, output)
    metadata = image_metadata(file)

    return if metadata.blank?

    watermark_image(file, output, metadata)

    output
  end

  private

  def watermark_image(file, output, metadata)
    MiniMagick.convert do |convert|
      setup_conversion_commands(convert, file)
      apply_watermark(convert, metadata)
      convert << output.to_path
    end
  end

  def setup_conversion_commands(convert, file)
    convert << file.to_path
    convert << "-pointsize"
    convert << POINTSIZE
    convert << "-kerning"
    convert << KERNING
    convert << "-fill"
    convert << FILL_COLOR
    convert << "-gravity"
    convert << "northwest"
  end

  # Parcourt l’image ligne par ligne et colonne par colonne en y apposant un filigrane
  # en alternant un décalage horizontal sur chaque ligne
  def apply_watermark(convert, metadata)
    stride_x, stride_y, initial_offsets_x, initial_offset_y = calculate_watermark_params

    0.step(by: stride_y, to: metadata[:height] + stride_y * 2).with_index do |offset_y, index|
      initial_offset_x = initial_offsets_x[index % 2]

      0.step(by: stride_x, to: metadata[:width] + stride_x * 2) do |offset_x|
        x = initial_offset_x + offset_x
        y = initial_offset_y + offset_y
        draw_text(convert, x, y)
      end
    end
  end

  def calculate_watermark_params
    # Approximation de la longueur du texte, qui marche bien pour les constantes par défaut
    char_width_approx = POINTSIZE / 2
    char_height_approx = POINTSIZE * 3 / 4

    # Dimensions du rectangle de texte
    text_width_approx = char_width_approx * text_length * Math.cos(ANGLE * (Math::PI / 180)).abs
    text_height_approx = char_width_approx * text_length * Math.sin(ANGLE * (Math::PI / 180)).abs + char_height_approx
    diagonal_length = Math.sqrt(text_width_approx**2 + text_height_approx**2)

    # Calcul des décalages entre chaque colonne et ligne
    # afin que chaque occurence "suive" la précédente
    stride_x = ((diagonal_length + char_width_approx) / Math.cos(ANGLE * (Math::PI / 180)))
    stride_y = text_height_approx

    initial_offsets_x = [0, (0 - stride_x / 2).round] # Motif de damier en alternant le décalage horizontal
    initial_offset_y = 0 - stride_y # Offset négatif pour mieux couvrir le nord ouest

    [stride_x.round, stride_y.round, initial_offsets_x, initial_offset_y.round]
  end

  def draw_text(convert, x, y)
    # A chaque insertion de texte, positionne le curseur, définit la rotation, puis réinitialise ces paramètres pour la prochaine occurence
    # Note: x and y can be negative value
    convert << "-draw"
    convert << "translate #{x},#{y} rotate #{-ANGLE} text 0,0 '#{text}' rotate #{ANGLE} translate #{-x},#{-y}"
  end

  def image_metadata(file)
    read_image(file) do |image|
      width = image.width
      height = image.height

      if rotated_image?(image)
        width, height = height, width
      end

      { width: width, height: height }
    end
  end

  def read_image(file)
    image = MiniMagick::Image.new(file.to_path)

    if image.valid?
      yield image
    else
      Rails.logger.info "Skipping image analysis because ImageMagick doesn't support the file #{file}"
      nil
    end
  end

  def rotated_image?(image)
    ['RightTop', 'LeftBottom'].include?(image["%[orientation]"])
  end
end
