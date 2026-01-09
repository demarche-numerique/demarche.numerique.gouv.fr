# frozen_string_literal: true

namespace :lint do
  desc 'Check for incorrect French apostrophes in view files'
  task :french_apostrophe do
    require 'fileutils'

    patterns = [
      /l['']/, # l'adresse -> lʼadresse
      /d['']/, # d'accord -> dʼaccord
      /n['']/, # n'est -> nʼest
      /j['']/, # j'ai -> jʼai
      /m['']/, # m'inscrire -> mʼinscrire
      /s['']/, # s'inscrire -> sʼinscrire
      /c['']/, # c'est -> cʼest
      /qu['']/, # qu'il -> quʼil
      /aujourd['']/, # aujourd'hui -> aujourdʼhui
      /quelqu['']/, # quelqu'un -> quelquʼun
    ]

    extensions = %w[.haml .erb .html .yml .yaml]
    directories = [
      'app/views',
      'app/components',
      'config/locales',
    ]

    offenses = []

    directories.each do |dir|
      next unless Dir.exist?(dir)

      Dir.glob("#{dir}/**/*").each do |file|
        next unless File.file?(file)
        next unless extensions.include?(File.extname(file))

        content = File.read(file)
        patterns.each do |pattern|
          content.scan(pattern) do |_match|
            match_data = Regexp.last_match
            line_number = content[0...match_data.begin(0)].count("\n") + 1
            offenses << {
              file: file,
              line: line_number,
              match: match_data[0],
            }
          end
        end
      end
    end

    if offenses.any?
      puts "\n❌ Found #{offenses.size} offense(s) using incorrect French apostrophes:"
      puts "\nUse 'ʼ' (U+02BC) instead of ''' or '''\n\n"
      offenses.each do |offense|
        puts "  #{offense[:file]}:#{offense[:line]}"
        puts "    Found: #{offense[:match]}"
      end
      puts
      exit 1
    else
      puts "✅ No offenses found for French apostrophes"
    end
  end
end
