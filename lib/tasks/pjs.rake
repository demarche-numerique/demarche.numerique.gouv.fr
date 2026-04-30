# frozen_string_literal: true

namespace :pjs do
  task stats: :environment do
  end

  desc <<~EOD
    bin/rake 'pjs:migrate['aa']'
    bin/rake 'pjs:migrate['aa-ab-ac']'
  EOD
  task :migrate, [:prefixes] => :environment do |_t, args|
    # [a-b] => "key LIKE 'a%' or key LIKE 'b%'"
    prefix_like_query = args[:prefixes]
      .split('-')
      .map { "key LIKE '#{_1}%'" }
      .join(' or ')

    blobs = ActiveStorage::Blob
      .where(prefix_like_query)
      .where.not("key LIKE '%/%'") # do not touch already moved blob

    blobs_count = blobs.count
    rake_puts "targeted prefix: #{args[:prefixes]}, #{blobs_count} blobs"

    blobs.in_batches { |batch| batch.ids.each { |id| PjsMigrationJob.perform_later(id) } }
  end

  desc "Watermark demo. Usage: noglob rake pjs:watermark_demo[tmp/carte-identite-demo-1.jpg]"
  task :watermark_demo, [:file_path] => :environment do |_t, args|
    require "vips"

    file = Pathname.new(args[:file_path])
    output_file = Rails.root.join('tmp', "#{file.basename(file.extname)}_watermarked#{file.extname}")
    format = file.extname.downcase.in?(['.jpg', '.jpeg']) ? 'image/jpeg' : 'image/png'

    image = Vips::Image.new_from_file(file.to_s, access: :sequential)
    watermarked = WatermarkService.new.apply(image, format: format)
    watermarked.write_to_file(output_file.to_s)

    rake_puts "Watermarked: #{output_file}"
  rescue WatermarkService::Error => e
    rake_puts "File #{file} not watermarked: #{e.message}"
  end

  desc "Watermark demo all defined demo files. Usage: noglob rake pjs:watermark_demo_all"
  task :watermark_demo_all => :environment do
    # You must have these filenames in tmp/ to run this demo (download ID cards specimens)
    filenames = [
      "carte-identite-demo-1.jpg", "carte-identite-demo-2.jpg", "carte-identite-demo-3.png", "carte-identite-demo-4.jpg",
      "carte-identite-demo-5.jpg", "passeport-1.jpg", "passeport-2.jpg",
    ]

    filenames.each do |file|
      Rake::Task["pjs:watermark_demo"].invoke("tmp/#{file}")
      Rake::Task["pjs:watermark_demo"].reenable
    end
  end
end
