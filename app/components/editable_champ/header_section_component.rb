# frozen_string_literal: true

class EditableChamp::HeaderSectionComponent < ApplicationComponent
  attr_reader :with_visual_heading

  def initialize(form: nil, champ:, seen_at: nil, html_class: {}, with_visual_heading: true)
    @champ = champ
    @html_class = html_class
    @with_visual_heading = with_visual_heading
  end

  def level
    @champ.level + 2 # The first title level should be a <h3>
  end

  def collapsible?
    @champ.level == 1
  end

  def libelle
    @champ.libelle
  end

  def header_section_classnames
    base = {
      "section-#{level}": true,
      'header-section': @champ.dossier.auto_numbering_section_headers_for?(@champ.type_de_champ),
      'hidden': !@champ.visible?,
    }

    # Accessibility:
    # A hidden <h2> ("Formulaire") is injected above the form to fix
    # the document heading structure. We decrement the DSFR visual
    # heading level so the UI appearance remains unchanged.
    base["fr-h#{level - 1}"] = true if with_visual_heading

    class_names(base.merge(@html_class))
  end

  def tag_for_depth
    if level <= 6
      "h#{level}"
    else
      "p"
    end
  end
end
