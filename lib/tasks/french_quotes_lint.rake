# frozen_string_literal: true

namespace :lint do
  desc 'Check that french translation files quote with « », not “ ”, " " or ‘ ’ (see GLOSSARY.md, UI copy policy)'
  task :french_quotes do
    forbidden_quotes = /[“”"‘‚„‹›]/
    html_tag = /<[^>]*>/

    each_string = -> (node, key, &block) do
      case node
      when Hash then node.each { |k, v| each_string.(v, [key, k].compact.join('.'), &block) }
      when Array then node.each_with_index { |v, i| each_string.(v, "#{key}.#{i}", &block) }
      when String then block.(key, node)
      end
    end

    files = Dir.glob('{config/locales,app/components}/**/{*.fr,fr}.yml')
    offenses = []

    files.each do |file|
      each_string.(YAML.load_file(file, aliases: true), nil) do |key, value|
        next if key.end_with?('prefill_query_response_html')
        offenses << "  #{file}: #{key}: #{value.squish.truncate(80)}" if value.gsub(html_tag, '').match?(forbidden_quotes)
      end
    end

    if offenses.any?
      puts offenses, "\n❌ Found #{offenses.size} translation(s) with “ ”, \" \" or ‘ ’ in french translation files: use « » with non-breaking spaces inside"
      exit 1
    end

    puts "✅ No “ ”, \" \" or ‘ ’ found in french translation files"
  end
end
