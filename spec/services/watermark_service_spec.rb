# frozen_string_literal: true

RSpec.describe WatermarkService, :external_deps do
  let(:image) { file_fixture("logo_test_procedure.png") }
  let(:watermark_service) { WatermarkService.new }

  describe '#apply' do
    before { require "vips" }

    it 'returns a Vips::Image with watermark applied on PNG' do
      image = Vips::Image.new_from_file(file_fixture("logo_test_procedure.png").to_path)
      result = watermark_service.apply(image, format: "image/png")

      expect(result).to be_a(Vips::Image)
      expect(result.width).to eq(image.width)
      expect(result.height).to eq(image.height)
      expect(result.has_alpha?).to be true
    end

    it 'flattens alpha when format is JPEG' do
      image = Vips::Image.new_from_file(file_fixture("image-no-exif.jpg").to_path)
      result = watermark_service.apply(image, format: "image/jpeg")

      expect(result).to be_a(Vips::Image)
      expect(result.has_alpha?).to be false
    end

    it 'raises WatermarkService::Error on Vips failure' do
      image = Vips::Image.new_from_file(file_fixture("logo_test_procedure.png").to_path)
      allow(image).to receive(:colourspace).and_raise(Vips::Error.new("boom"))

      expect { watermark_service.apply(image, format: "image/png") }.to raise_error(WatermarkService::Error, /boom/)
    end
  end
end
