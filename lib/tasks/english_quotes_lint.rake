# frozen_string_literal: true

namespace :lint do
  desc 'Check that english translation files use no french guillemets (see GLOSSARY.md, UI copy policy)'
  task :english_quotes do
    files = Dir.glob('{config/locales,app/components}/**/{*.en,en}.yml')
    offenses = files.flat_map do |file|
      File.readlines(file).each_with_index.filter_map do |line, i|
        "  #{file}:#{i + 1}: #{line.strip.truncate(80)}" if line.match?(/[«»]/)
      end
    end

    if offenses.any?
      puts offenses, "\n❌ Found « » in english translation files: use ‘…’ around a name or a term"
      exit 1
    end

    puts "✅ No french guillemets found in english translation files"
  end
end
