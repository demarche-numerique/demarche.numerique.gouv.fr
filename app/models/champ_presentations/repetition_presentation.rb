# frozen_string_literal: true

class ChampPresentations::RepetitionPresentation < ChampPresentations::BasePresentation
  attr_reader :libelle
  attr_reader :rows

  def initialize(libelle, rows)
    @libelle = libelle
    @rows = rows
  end

  def to_s
    ([libelle] + rows.map do |row|
      row.flat_champs.map do |champ|
        "#{champ.libelle} : #{champ}"
      end.join("\n")
    end).join("\n\n")
  end

  def to_tiptap_node
    {
      type: 'orderedList',
      attrs: { class: 'tdc-repetition' },
      content: rows.map do |row|
        {
          type: 'listItem',
          content: [
            {
              type: 'descriptionList',
              content: row.flat_champs.map do |champ|
                [
                  {
                    type: 'descriptionTerm',
                    attrs: champ.blank? ? { class: 'invisible' } : nil, # still render libelle so width & alignment are preserved
                    content: [
                      {
                        type: 'text',
                        text: champ.libelle,
                      },
                    ],
                  }.compact,
                  {
                    type: 'descriptionDetails',
                    content: [
                      {
                        type: 'text',
                        text: champ.to_s,
                      },
                    ],
                  },
                ]
              end.flatten,
            },
          ],
        }
      end,
    }
  end
end
