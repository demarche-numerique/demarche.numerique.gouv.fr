# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dossiers::ErrorsFullMessagesComponent, type: :component do
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:types_de_champ_public) { [type: :text] }
  let(:dossier) { create(:dossier, procedure:) }
  let(:component) { described_class.new(dossier:) }

  describe 'render' do
    context 'when dossier does not have any error' do
      subject { render_inline(component).to_html }
      it 'does not render' do
        expect(subject).to eq("")
      end
    end

    context 'when dossier have error' do
      let(:champ) { dossier.project_champs_public.first.writable! }

      subject do
        dossier.validate(:champs_public_value)
        dossier.champs_public_valid?
        render_inline(component).to_html
      end

      context 'when champ is repetition' do
        let(:champ_repetition) { dossier.project_champs_public.first }
        let(:rows) { champ_repetition.rows }
        let(:champ_child) { rows.first.first }

        let(:types_de_champ_public) { [{ libelle: "Champ parent", type: :repetition, children: [{ libelle: "Champ enfant", type: :text }] }] }

        it 'focuses on focusable_input_id' do
          expect(subject).to have_link(champ_child.libelle, href: "##{champ_child.focusable_input_id}")
        end

        it "renders the model libelle with the parent libelle and the row number" do
          expect(subject).to have_text("Champ parent - [1] Champ enfant")
        end

        context "when there is more than one child" do
          let(:types_de_champ_public) { [{ libelle: "Champ parent", type: :repetition, children: [{ libelle: "Premier champ", type: :text }, { libelle: "Second enfant", type: :text }] }] }

          it do
            expect(subject).to have_text("[1] Champ parent - Premier champ")
            expect(subject).to have_text("[1] Champ parent - Second enfant")
          end
        end
      end

      context 'when champ is civilite' do
        let(:types_de_champ_public) { [{ type: :civilite }] }
        it 'focuses on focusable_input_id' do
          expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id}")
        end
      end

      context 'when champ is epci' do
       let(:types_de_champ_public) { [{ type: :epci, mandatory: true }] }
       before { champ.update(attributes) }

       context 'when nothing is filled' do
         let(:attributes) { { value: nil, value_json: nil } }
         it 'focuses on focusable_input_id' do
           expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id(:value)}", count: 1)
         end
       end

       context 'when departement is not selected' do
         let(:attributes) { { value: nil, value_json: { code_departement: nil, name: nil } } }

         it 'focuses on focusable_input_id' do
           expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id(:value)}", count: 1)
         end
       end

       context 'when name is not selected' do
         let(:attributes) { { value: nil, value_json: { code_departement: '95', name: nil } } }

         it 'focuses on focusable_input_id' do
           expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id(:value)}", count: 1)
         end
       end
     end

      context 'when champ is drop_down_list as radio' do
        let(:types_de_champ_public) { [{ type: :drop_down_list, options: %w[first_option other ones] }] }
        it 'focuses on focusable_input_id (first option)' do
          expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id}")
        end
      end

      context 'when champ is drop_down_list as combobox' do
        let(:types_de_champ_public) { [{ type: :drop_down_list, options: %w[a b c d e f] }] }
        it 'focuses on focusable_input_id (first option)' do
          expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id}")
        end
      end

      context 'when champ is multiple_drop_down_list' do
        let(:types_de_champ_public) { [{ type: :multiple_drop_down_list }] }
        it 'focuses on focusable_input_id' do
          expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id}")
        end
      end

      context 'when champ is linked_drop_down_list' do
        let(:options) { ['--Primary 1--', 'Secondary 1.1', 'Secondary 1.2'] }
        let(:types_de_champ_public) do
          [{ type: :linked_drop_down_list, libelle: 'Ville', options:, mandatory: true }]
        end

        context 'when the primary value is blank' do
          it 'shows the primary libelle and links to the primary select' do
            expect(subject).to have_link('Ville', href: "##{champ.focusable_input_id(:value)}")
          end
        end

        context 'when the primary value is set but the secondary is blank' do
          before { champ.update!(value: JSON.generate(['Primary 1', ''])) }

          it 'shows the secondary libelle and links to the secondary select' do
            expect(subject).to have_link(
              I18n.t('shared.champs.linked_drop_down_list.secondary_default_libelle'),
              href: "##{champ.focusable_input_id(:secondary_value)}"
            )
          end
        end
      end

      context 'when champ is yes_no' do
        let(:types_de_champ_public) { [{ type: :yes_no }] }
        it 'focuses on focusable_input_id' do
          expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id}")
        end
      end

      context 'when the champ is simple text' do
        it 'does render' do
          expect(subject).to have_link(champ.type_de_champ.libelle, href: "##{champ.focusable_input_id}")
        end
      end

      context 'when champ is referentiel required and not filled' do
        let(:referentiel) { create(:api_referentiel, :exact_match) }
        let(:types_de_champ_public) { [{ type: :referentiel, referentiel:, mandatory: true }] }

        context 'when champ is referentiel and not filled' do
          before { champ.update(external_id: nil) }
          it 'focuses on focusable_input_id' do
            expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id}", count: 1)
          end
        end

        context 'when champ is referentiel and filled' do
          before { champ.update(external_id: 'kthxbye') }

          it 'focuses on focusable_input_id' do
            expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id}", count: 1)
          end
        end
      end

      context 'when champ is address not in ban' do
        let(:types_de_champ_public) { [{ type: :address, mandatory: true }] }
        let(:not_in_ban) { 'true' }
        before do
          champ.update(value_json: { not_in_ban:, country_code: })
        end

        context 'when country_code is FR' do
          let(:country_code) { 'FR' }
          it 'focuses on focusable_input_id' do
            expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id(:street_address)}", count: 1)
            expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id(:commune_name)}", count: 1)
          end
        end
        context 'when not in ban and country_code is not FR' do
          let(:country_code) { 'ES' }

          it 'focuses on focusable_input_id' do
            expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id(:street_address)}", count: 1)
            expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id(:city_name)}", count: 1)
            expect(subject).to have_link(champ.libelle, href: "##{champ.focusable_input_id(:postal_code)}", count: 1)
          end
        end
      end
    end
  end
end
