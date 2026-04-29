# frozen_string_literal: true

describe 'As an administrateur I can edit types de champ condition', js: true do
  include Logic

  let(:administrateur) { procedure.administrateurs.first }
  let(:procedure) do
    create(:procedure,
           types_de_champ_public: [
             { type: :integer_number, libelle: 'age' },
             { type: :text, libelle: 'nom du parent' },
           ])
  end

  let(:first_tdc) { procedure.draft_revision.types_de_champ.first }
  let(:second_tdc) { procedure.draft_revision.types_de_champ.second }

  before do
    login_as administrateur.user, scope: :user
    visit champs_admin_procedure_path(procedure)
  end

  shared_examples 'condition editor' do
    scenario 'add/remove/add condition' do
      within '.type-de-champ:nth-child(2)' do
        click_on 'cliquer pour activer'
        find('button[title="Supprimer la ligne"]').click
        click_on 'cliquer pour activer'
      end
    end

    scenario "adding a new condition" do
      within '.type-de-champ:nth-child(2)' do
        click_on 'cliquer pour activer'

        within '.condition-table tbody tr:nth-child(1)' do
          expect(page).to have_select('type_de_champ[condition_form][rows][][targeted_champ]', options: ['Sélectionner', 'age'])

          within('.target') { select('age') }
          within('.operator') { select('Supérieur ou égal à') }
          within('.value') { fill_in with: 18 }
        end
      end

      expected_condition = greater_than_eq(target_value, constant(18))
      wait_until { second_tdc.reload.condition == expected_condition }
    end

    scenario "the first type de champ is removed" do
      within '.type-de-champ:nth-child(1)' do
        accept_alert do
          click_on 'Supprimer'
        end
      end

      # the condition table is deleted
      expect(page).to have_no_content('Logique conditionnelle')
    end

    context 'with a preexisting condition' do
      before do
        second_tdc.update(condition: greater_than_eq(target_value, constant(18)))

        page.refresh
      end

      scenario "removing all conditions" do
        within '.type-de-champ:nth-child(2)' do
          accept_alert do
            click_on 'cliquer pour désactiver'
          end

          # the condition table is deleted
          expect(page).to have_no_table
        end
      end

      scenario "removing a condition" do
        within '.type-de-champ:nth-child(2)' do
          within '.condition-table tbody tr:nth-child(1)' do
            within('.delete-column') { click_on 'Supprimer la ligne' }
          end

          # the condition table is deleted
          expect(page).to have_no_table
        end
      end

      scenario "adding a second row" do
        within '.type-de-champ:nth-child(2)' do
          click_on 'Ajouter une condition'

          # the condition table has 2 rows
          within '.condition-table tbody' do
            expect(page).to have_selector('tr', count: 2)
          end
        end
      end

      scenario "changing target champ to a not managed type" do
        expect(page).to have_no_selector('.errors-summary')

        within '.type-de-champ:nth-child(1)' do
          select('Départements', from: 'Type de champ')
        end

        within '.type-de-champ:nth-child(2)' do
          expect(page).to have_selector('.errors-summary')
        end
      end

      scenario "moving a target champ below the condition" do
        expect(page).to have_no_selector('.errors-summary')

        within '.type-de-champ:nth-child(1)' do
          click_on 'Déplacer le champ vers le bas'
        end

        # the now first champ has an error
        within '.type-de-champ:nth-child(1)' do
          expect(page).to have_selector('.errors-summary')
        end
      end

      scenario "moving the condition champ above the target" do
        expect(page).to have_no_selector('.errors-summary')

        within '.type-de-champ:nth-child(2)' do
          click_on 'Déplacer le champ vers le haut'
        end

        # the now first champ has an error
        within '.type-de-champ:nth-child(1)' do
          expect(page).to have_selector('.errors-summary')
        end
      end
    end
  end

  context 'in champ_value mode' do
    let(:target_value) { champ_value(first_tdc.stable_id) }

    include_examples 'condition editor'
  end

  context 'in column_value mode' do
    before { Flipper.enable(:column_conditions) }
    after { Flipper.disable(:column_conditions) }

    let(:target_value) { column_value(first_tdc.columns(procedure:).first) }

    include_examples 'condition editor'
  end
end
