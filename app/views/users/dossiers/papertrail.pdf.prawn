# frozen_string_literal: true

require 'prawn/measurement_extensions'

#----- A4 page size
page_size = 'A4'
page_width = 595

# see, charte_graphique_de_letat.pdf
#   a4: 210mm largueur
#   margin left and right: 17mm
#   calc ratio, 17*100/210: 8% de marge gauche/droite
#   calc mm to pixel: 8*595/100: 47 <- final margin
#----- margins
top_margin = 47
right_margin = 47
bottom_margin = 47
left_margin = 47

body_width = page_width - left_margin - right_margin

prawn_document(margin: [top_margin, right_margin, bottom_margin, left_margin], page_size: page_size) do |pdf|
  pdf.font_families.update('marianne' => {
    normal: Rails.root.join('lib/prawn/fonts/marianne/marianne-regular.ttf'),
    bold: Rails.root.join('lib/prawn/fonts/marianne/marianne-bold.ttf'),
  })
  pdf.font 'marianne'
  pdf.fallback_fonts = ['Helvetica']

  grey = '3a3a3a'
  black = '222222'

  pdf.pad_bottom(30) do
    pdf.image DOSSIER_PDF_EXPORT_LOGO_SRC, width: 300, position: :center

    pdf.pad_top(15) do
      pdf.fill_color grey
      pdf.text t('.receipt'), size: 14, align: :center
      add_pdf_draft_warning(pdf, @dossier)
    end
  end

  pdf.bounding_box([0, pdf.cursor - 20], width: body_width) do
    pdf.fill_color black
    pdf.pad_top(40) { pdf.text @dossier.procedure.libelle, size: 14, character_spacing: -0.2, align: :center }

    pdf.fill_color grey
    description = t('.description', user_name: papertrail_requester_identity(@dossier), procedure: @dossier.procedure.libelle, date: l(@dossier.depose_at, format: '%e %B %Y'))
    pdf.pad_top(30) { pdf.text description, size: 10, character_spacing: -0.2, align: :left }

    pdf.fill_color black
    pdf.pad_top(30) { pdf.text t('views.shared.dossiers.demande.requester_identity'), size: 14, character_spacing: -0.2, align: :justify }

    if @dossier.individual.present?
      pdf.pad_top(7) do
        pdf.fill_color grey
        pdf.text "#{Individual.human_attribute_name(:prenom)} : #{@dossier.individual.prenom}", size: 10, character_spacing: -0.2, align: :justify
        pdf.text "#{Individual.human_attribute_name(:nom)} :  #{@dossier.individual.nom.upcase}", size: 10, character_spacing: -0.2, align: :justify
        pdf.text "#{User.human_attribute_name(:email)} :  #{@dossier.user_email_for(:display)}", size: 10, character_spacing: -0.2, align: :justify
      end
    end

    if @dossier.etablissement.present?
      pdf.pad_top(7) do
        pdf.fill_color grey
        pdf.text "Dénomination : " + raison_sociale_or_name(@dossier.etablissement), size: 10, character_spacing: -0.2, align: :justify
        pdf.text "SIRET : " + @dossier.etablissement.siret, size: 10, character_spacing: -0.2, align: :justify
        pdf.text "#{User.human_attribute_name(:email)} :  #{@dossier.user_email_for(:display)}", size: 10, character_spacing: -0.2, align: :justify
      end
    end

    pdf.fill_color black
    pdf.pad_top(30) { pdf.text Dossier.model_name.human, size: 14, character_spacing: -0.2, align: :justify }

    pdf.fill_color grey
    pdf.pad_top(7) do
      pdf.text "#{Dossier.human_attribute_name(:id)} : #{@dossier.id}", size: 10, character_spacing: -0.2, align: :justify
      pdf.text t('.file_submitted_at') + ' : ' + l(@dossier.depose_at, format: '%e %B %Y'), size: 10, character_spacing: -0.2, align: :justify
      pdf.text t('.dossier_state') + ' : ' + papertrail_dossier_state(@dossier), size: 10, character_spacing: -0.2, align: :justify
    end

    service_or_contact_information = @dossier.service_or_contact_information
    if service_or_contact_information.present?
      pdf.fill_color black
      pdf.pad_top(30) { pdf.text t('.administrative_service'), size: 14, character_spacing: -0.2, align: :justify }

      pdf.fill_color grey
      pdf.pad_top(7) do
        pdf.text "#{Service.model_name.human} : " + [service_or_contact_information.nom, service_or_contact_information.organisme].join(", "), size: 10, character_spacing: -0.2, align: :justify
        pdf.text "#{Service.human_attribute_name(:adresse)} : #{service_or_contact_information.adresse}", size: 10, character_spacing: -0.2, align: :justify
        if service_or_contact_information.email.present?
          pdf.text "#{Service.human_attribute_name(:email)} : #{service_or_contact_information.email}", size: 10, character_spacing: -0.2, align: :justify
        end
        if service_or_contact_information.telephone.present?
          pdf.text "#{Service.human_attribute_name(:telephone)} : #{service_or_contact_information.telephone}", size: 10, character_spacing: -0.2, align: :justify
        end
      end
    end

    pdf.fill_color black
    pdf.pad_top(100) do
      pdf.text t('.generated_at', date: l(Time.zone.now.to_date, format: :long)), size: 10, character_spacing: -0.2, align: :right
      pdf.text t('.signature', app_name: APPLICATION_NAME), size: 10, character_spacing: -0.2, align: :right
    end
  end
end
