# frozen_string_literal: true

class WatermarkService
  class Error < StandardError; end

  POINTSIZE = 20
  ANGLE = 45
  FILL_COLOR = [0, 0, 0]
  OPACITY = 0.4

  attr_reader :text

  def initialize(text = APPLICATION_NAME)
    @text = " #{text} " # give more space around each occurrence
  end

  def apply(image, format:)
    require "vips"

    image = image.colourspace(:srgb)
    image = image.bandjoin(255) unless image.has_alpha?
    watermarked = image.composite(build_watermark_overlay(image.width, image.height), :over)
    jpeg_format?(format) ? watermarked.flatten : watermarked
  rescue Vips::Error => e
    raise Error, e.message, e.backtrace
  end

  private

  def jpeg_format?(format)
    format.in?(["image/jpeg", "image/jpg"])
  end

  PADDING_RATIO = 0.25 # espacement entre chaque occurrence du filigrane

  # Parcourt l'image en y apposant un filigrane en mosaïque de texte en diagonal
  # avec un motif en damier (décalage d'un demi-tile sur les lignes impaires)
  def build_watermark_overlay(width, height)
    text_image = Vips::Image.text(text, font: "sans #{POINTSIZE}", dpi: 72)
    rotated_text = text_image.rotate(-ANGLE)
    colored_text = colorize_text(rotated_text)

    # Ajouter du padding autour du texte pour espacer les occurrences
    pad_x = (colored_text.width * PADDING_RATIO).round
    pad_y = (colored_text.height * PADDING_RATIO).round
    tile = colored_text.embed(pad_x, pad_y, colored_text.width + pad_x * 2, colored_text.height + pad_y * 2)

    tile_w = tile.width
    tile_h = tile.height

    # Construire 2 rangées : normale et décalée d'un demi-tile (motif damier)
    row_across = (width.to_f / tile_w).ceil + 3
    row = tile.replicate(row_across, 1)
    shifted_row = row.crop(tile_w / 2, 0, (row_across - 1) * tile_w + tile_w / 2, tile_h)

    brick = row.crop(0, 0, shifted_row.width, tile_h).join(shifted_row, :vertical)

    # Répliquer verticalement pour couvrir la hauteur
    down = (height.to_f / (tile_h * 2)).ceil + 2
    tiled = brick.replicate(1, down)

    # Crop avec un décalage pour mieux couvrir les bords
    tiled.crop(tile_w / 2, tile_h / 2, [width, tiled.width - tile_w / 2].min, [height, tiled.height - tile_h / 2].min)
  end

  def colorize_text(text_image)
    alpha = (text_image.cast(:float) * OPACITY).cast(:uchar)

    rgb = text_image.new_from_image(FILL_COLOR).copy(interpretation: :srgb)
    rgb.bandjoin(alpha)
  end
end
