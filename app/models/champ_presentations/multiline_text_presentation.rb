# frozen_string_literal: true

# Free text spanning several lines (the motivation of a decision): a text
# node per line separated by hard breaks, so the value stays inside the
# paragraph that mentions it.
class ChampPresentations::MultilineTextPresentation < ChampPresentations::BasePresentation
  attr_reader :text

  def initialize(text)
    @text = text.to_s.gsub("\r\n", "\n").strip
  end

  def to_s = text

  def to_tiptap_nodes
    text.split("\n").flat_map.with_index do |line, index|
      [({ type: 'hardBreak' } if index > 0), ({ type: 'text', text: line } unless line.empty?)].compact
    end
  end
end
