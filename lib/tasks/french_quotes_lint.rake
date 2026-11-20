# frozen_string_literal: true

namespace :lint do
  desc 'Check that french translation files quote with « » and non-breaking spaces inside, not “ ”, " " or ‘ ’ (see GLOSSARY.md, UI copy policy)'
  task :french_quotes do
    rules = {
      /[“”"‘‚„‹›]/ => 'use « » instead of “ ”, " " or ‘ ’',
      /«(?![  ])|(?<![  ])»/ => 'put a non-breaking space inside « »',
    }
    html_tag = /<[^>]*>/
    html_nbsp = /&nbsp;|&#160;/

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
        text = value.gsub(html_tag, '').gsub(html_nbsp, " ")
        rules.each do |pattern, advice|
          offenses << "  #{file}: #{key}: #{advice}: #{value.squish.truncate(80)}" if text.match?(pattern)
        end
      end
    end

    if offenses.any?
      puts offenses, "\n❌ Found #{offenses.size} translation(s) with misused quotation marks in french translation files"
      exit 1
    end

    puts "✅ No misused quotation marks found in french translation files"
  end
end
