# frozen_string_literal: true

describe Typst::Payload do
  describe '#to_h' do
    let(:payload_class) do
      Class.new(described_class) do
        def build
          { title: "Bonjour \u{1F44B} !", items: [" point", { note: "﻿ok\tbien" }], count: 3, flag: true, none: nil }
        end
      end
    end

    it 'sanitizes every string of the built hash, at any depth, and leaves the other values alone' do
      expect(payload_class.new.to_h).to eq(title: 'Bonjour  !', items: ['• point', { note: 'ok bien' }], count: 3, flag: true, none: nil)
    end

    it 'requires the subclass to build the hash' do
      expect { Class.new(described_class).new.to_h }.to raise_error(NotImplementedError)
    end
  end

  describe '.sanitize_text' do
    def sanitize(text) = described_class.sanitize_text(text)

    it 'keeps letters, accents, French punctuation and the symbols the fonts display' do
      text = "À envoyer avant le 1ᵉʳ mars : « oui » ✔ ☐ → ★ © 12 € (50 %)\nLigne 2"
      expect(sanitize(text)).to eq(text)
    end

    it 'turns tabs into spaces and drops the other control characters' do
      expect(sanitize("a\tbcde\r\nf")).to eq("a bcde\nf")
    end

    it 'drops the byte order mark, zero-width characters and variation selectors' do
      expect(sanitize("﻿no​n‍⁠️")).to eq('non')
    end

    it 'drops emoji, whatever their presentation, with their skin tone, flag and keycap sequences' do
      text = "Bienvenue \u{1F44B} ! \u{1F4A1} idée \u{1F5D3} ✅ ⛔ \u{1F44D}\u{1F3FD} \u{1F1EB}\u{1F1F7} 1️⃣ \u{1F468}‍\u{1F469}‍\u{1F467} fin"
      expect(sanitize(text)).to eq('Bienvenue  !  idée      1  fin')
    end

    it 'replaces the private use codes Word pastes for its bullets with the characters they stood for' do
      expect(sanitize(" point\n sous-point\n suite\n fait")).to eq("• point\n▪ sous-point\n➢ suite\n✔ fait")
    end

    it 'replaces odd punctuation with the look-alike the fonts display' do
      expect(sanitize("a\u2E31b \uFFEB c\uA78Fd")).to eq('a·b → c·d')
    end

    it 'drops the other private use characters' do
      expect(sanitize("abc\u{F0001}d")).to eq('abcd')
    end
  end
end
