# frozen_string_literal: true

require 'prawn/measurement_extensions'

# Render text in a box that expands vertically, then move the cursor down to the end of the rendered text
def render_expanding_text_box(pdf, text, options)
  box = Prawn::Text::Box.new(text, options.merge(document: pdf, overflow: :expand))

  box.render(dry_run: true)
  vertical_space_used = box.height

  box.render
  pdf.move_down(vertical_space_used)
end

def render_in_2_columns(pdf, label, text)
  pdf.text_box label, width: 200, height: 100, overflow: :expand, at: [0, pdf.cursor]
  pdf.text_box ":", width: 10, height: 100, overflow: :expand, at: [100, pdf.cursor]
  render_expanding_text_box(pdf, text, width: 420, height: 100, at: [110, pdf.cursor])
  pdf.text "\n"
end

def empty_format_in_2_lines(pdf, champ, nb_lines = 1)
  add_single_line(pdf, champ.libelle, 9, :bold)
  add_optionnal_description(pdf, champ)
  height = 10 * (nb_lines + 1)
  pdf.bounding_box([0, pdf.cursor], :width => 460, :height => height) do
    pdf.stroke_bounds
  end
  pdf.text "\n"
end

def empty_format_in_2_columns(pdf, label)
  pdf.text_box label, width: 200, height: 100, overflow: :expand, at: [0, pdf.cursor]
  pdf.bounding_box([110, pdf.cursor + 5], :width => 350, :height => 20) do
    pdf.stroke_bounds
  end

  pdf.text "\n"
end

def format_with_checkbox(pdf, option, offset = 0)
  # Option is a [text, value] pair, or a string used for both.
  label = option.is_a?(String) ? option : option.first
  value = option.is_a?(String) ? option : option.last

  if value == Champs::DropDownListChamp::OTHER
    label += " : "
  end

  pdf.font 'marianne', size: 9 do
    # Ensure enough space for checkbox + text to avoid orphaned checkboxes at page breaks
    if pdf.cursor < (pdf.bounds.bottom + 40)
      pdf.start_new_page
    end

    pdf.stroke_rectangle [0 + offset, pdf.cursor], 10, 10
    render_expanding_text_box(pdf, label, at: [15, pdf.cursor])

    if value == Champs::DropDownListChamp::OTHER
      pdf.bounding_box([110, pdf.cursor + 3], :width => 350, :height => 20) do
        pdf.stroke_bounds
      end
    end
  end
  pdf.text "\n"
end

def add_page_numbering(pdf)
  # This method should be called at the end of the drawing since pages drawn after
  # do not have page numbering
  string = '<page> / <total>'
  options = {
    at: [0, -15],
    align: :right,
  }
  pdf.number_pages string, options
end

def add_procedure(pdf, procedure)
  pdf.repeat(lambda { |page| page > 1 }) do
    pdf.draw_text procedure.libelle, :at => pdf.bounds.top_left
  end
end

def format_date(date)
  I18n.l(date, format: :message_date_with_year)
end

def empty_add_identite_individual(pdf)
  empty_format_in_2_columns(pdf, "Civilité")
  empty_format_in_2_columns(pdf, "Nom")
  empty_format_in_2_columns(pdf, "Prénom")

  if @procedure.ask_birthday?
    empty_format_in_2_columns(pdf, "Date de naissance")
  end
end

def empty_add_identite_etablissement(pdf, libelle)
  add_single_line(pdf, libelle, 9, :bold)

  empty_format_in_2_columns(pdf, "SIRET")
  empty_format_in_2_columns(pdf, "Dénomination")
  empty_format_in_2_columns(pdf, "Forme juridique")
end

def add_single_line(pdf, libelle, size, style)
  pdf.font 'marianne', style: style, size: size do
    pdf.text libelle
  end
end

def empty_add_title(pdf, title)
  add_single_line(pdf, title, 20, :bold)
  pdf.text "\n"
end

def add_libelle(pdf, type_de_champ)
  add_single_line(pdf, type_de_champ.libelle, 9, :bold)
end

def add_explanation(pdf, explanation)
  add_single_line(pdf, explanation, 9, :italic)
end

def add_optionnal_description(pdf, type_de_champ)
  add_explanation(pdf, strip_tags(type_de_champ.description).strip + "\n\n") if type_de_champ.description.present?
end

def render_single_champ(pdf, revision, type_de_champ)
  case type_de_champ.type_champ
  when TypeDeChamp.type_champs.fetch(:repetition)
    add_libelle(pdf, type_de_champ)
    types_de_champ = type_de_champ.flat_children

    3.times do
      types_de_champ.each do |type_de_champ|
        render_single_champ(pdf, revision, type_de_champ)
      end
    end
  when TypeDeChamp.type_champs.fetch(:piece_justificative)
    add_single_line(pdf, 'Pièce justificative à joindre en complément du dossier', 9, :bold)
    format_with_checkbox(pdf, type_de_champ.libelle)
    add_optionnal_description(pdf, type_de_champ)
    pdf.text "\n"
  when TypeDeChamp.type_champs.fetch(:yes_no), TypeDeChamp.type_champs.fetch(:checkbox)
    add_libelle(pdf, type_de_champ)
    add_optionnal_description(pdf, type_de_champ)
    add_explanation(pdf, 'Cochez la mention applicable')
    format_with_checkbox(pdf, 'Oui')
    format_with_checkbox(pdf, 'Non')
    pdf.text "\n"
  when TypeDeChamp.type_champs.fetch(:civilite)
    add_libelle(pdf, type_de_champ)
    add_optionnal_description(pdf, type_de_champ)
    format_with_checkbox(pdf, Individual::GENDER_FEMALE)
    format_with_checkbox(pdf, Individual::GENDER_MALE)
    pdf.text "\n"
  when TypeDeChamp.type_champs.fetch(:header_section)
    add_single_line(pdf, type_de_champ.libelle, 14, :bold)
    add_optionnal_description(pdf, type_de_champ)
    pdf.text "\n"
  when TypeDeChamp.type_champs.fetch(:explication)
    add_libelle(pdf, type_de_champ)
    pdf.text type_de_champ.description
    pdf.text "\n"
  when TypeDeChamp.type_champs.fetch(:address), TypeDeChamp.type_champs.fetch(:carte), TypeDeChamp.type_champs.fetch(:textarea)
    empty_format_in_2_lines(pdf, type_de_champ, 5)
  when TypeDeChamp.type_champs.fetch(:drop_down_list)
    if type_de_champ.drop_down_advanced?
      empty_format_in_2_lines(pdf, type_de_champ)
    else
      add_libelle(pdf, type_de_champ)
      add_optionnal_description(pdf, type_de_champ)
      add_explanation(pdf, 'Cochez la mention applicable, une seule valeur possible')
      type_de_champ.drop_down_options.each do |option|
        format_with_checkbox(pdf, option)
      end
      pdf.text "\n"
    end
  when TypeDeChamp.type_champs.fetch(:multiple_drop_down_list)
    add_libelle(pdf, type_de_champ)
    add_optionnal_description(pdf, type_de_champ)
    add_explanation(pdf, 'Cochez la mention applicable, plusieurs valeurs possibles')
    type_de_champ.drop_down_options.each do |option|
      format_with_checkbox(pdf, option)
    end
    pdf.text "\n"
  when TypeDeChamp.type_champs.fetch(:linked_drop_down_list)
    add_libelle(pdf, type_de_champ)
    type_de_champ.primary_options.compact_blank.each do |o|
      format_with_checkbox(pdf, o)
      type_de_champ.secondary_options[o].compact_blank.each do |secondary_option|
        format_with_checkbox(pdf, secondary_option, 15)
      end
    end
    pdf.text "\n"
  when TypeDeChamp.type_champs.fetch(:siret)
    empty_add_identite_etablissement(pdf, type_de_champ.libelle)
  else
    empty_format_in_2_lines(pdf, type_de_champ)
  end
end

def empty_add_champs(pdf, revision, types_de_champ)
  types_de_champ.each do |type_de_champ|
    render_single_champ(pdf, revision, type_de_champ)
  end
end

prawn_document(page_size: "A4") do |pdf|
  pdf.font_families.update('marianne' => {
    normal: Rails.root.join('lib/prawn/fonts/marianne/marianne-regular.ttf'),
    bold: Rails.root.join('lib/prawn/fonts/marianne/marianne-bold.ttf'),
    italic: Rails.root.join('lib/prawn/fonts/marianne/marianne-thin.ttf'),
  })
  pdf.font 'marianne'
  pdf.fallback_fonts = ['Helvetica']
  pdf.image DOSSIER_PDF_EXPORT_LOGO_SRC, width: 300, position: :center
  pdf.move_down(40)

  render_in_2_columns(pdf, 'Démarche', @procedure.libelle)
  render_in_2_columns(pdf, 'Organisme', @procedure.organisation_name || "En attente de saisi")
  pdf.text "\n"

  empty_add_title(pdf, "Identité du demandeur")

  empty_format_in_2_columns(pdf, "Email")

  if @procedure.for_individual?
    empty_add_identite_individual(pdf)
  else
    empty_add_identite_etablissement(pdf, 'Etablissement')
  end
  pdf.text "\n"

  empty_add_title(pdf, 'Formulaire')
  add_single_line(pdf, @procedure.description + "\n", 9, :italic) if @procedure.description.present?
  empty_add_champs(pdf, @revision, @revision.root_public_types_de_champ)
  add_page_numbering(pdf)
  add_procedure(pdf, @procedure)
end
