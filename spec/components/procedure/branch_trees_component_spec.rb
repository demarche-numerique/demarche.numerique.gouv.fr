# frozen_string_literal: true

describe Procedure::BranchTreesComponent, type: :component do
  include Logic

  let(:procedure) { create(:procedure, public_type_de_champs:) }
  let(:revision) { procedure.draft_revision }

  subject(:rendered) { render_inline(described_class.new(revision:, branch_trees: revision.branch_trees)) }

  context 'without conditions' do
    let(:public_type_de_champs) { [{ type: :yes_no, libelle: 'Majeur' }] }

    it { expect(rendered).to have_text('Ce formulaire ne comporte aucune condition.') }
  end

  context 'with conditions' do
    let(:public_type_de_champs) do
      [
        { type: :drop_down_list, libelle: 'Situation', mandatory: true, stable_id: 1, drop_down_options: ['Salarié', 'Indépendant', 'Retraité'] },
        { type: :integer_number, libelle: 'Âge', mandatory: false, stable_id: 2 },
        { type: :piece_justificative, libelle: 'Contrat', mandatory: true, condition: ds_eq(champ_value(1), constant('Salarié')) },
        { type: :text, libelle: 'Autorisation', mandatory: true, condition: ds_and([ds_eq(champ_value(1), constant('Salarié')), less_than(champ_value(2), constant(18))]) },
        { type: :text, libelle: 'Revenus', mandatory: true, condition: ds_not_eq(champ_value(1), constant('Salarié')) },
        { type: :text, libelle: 'Jamais', mandatory: true, condition: ds_and([ds_eq(champ_value(1), constant('Salarié')), ds_eq(champ_value(1), constant('Retraité'))]) },
      ]
    end

    it 'renders the tree, the durations and the warnings' do
      rendered

      expect(page).to have_css('button.fr-accordion__btn[aria-expanded="true"]', text: 'Selon « Situation » et « Âge »')
      expect(page).to have_text('Situation : Salarié')
      expect(page).to have_text('Âge : 17 ou moins')
      expect(page).to have_text('Âge : 18 ou plus, non renseigné')
      expect(page).to have_text('Situation : Indépendant, Retraité')
      expect(page).to have_link('Contrat', href: /#type_de_champ_editor_procedure_revision_type_de_champ_\d+/)
      expect(page).to have_text('2 champs, environ 3 min')
      expect(page).to have_text('1 champ, environ 3 min')
      expect(page).to have_text('1 champ, environ 1 min')
      expect(page).to have_text('Aucune réponse n’affiche le champ « Jamais ».')
    end
  end

  context 'with a single branching champ' do
    let(:public_type_de_champs) do
      [
        { type: :yes_no, libelle: 'Majeur', mandatory: true, stable_id: 1 },
        { type: :text, libelle: 'Tuteur', mandatory: true, condition: ds_eq(champ_value(1), constant(false)) },
      ]
    end

    it 'tells the answer that displays nothing' do
      expect(rendered).to have_text('Aucun champ supplémentaire')
    end

    context 'when the cluster is too big to detail' do
      before { stub_const('Logic::Branches::MAX_BRANCHES', 1) }

      it { expect(rendered).to have_text('Ce groupe combine trop de réponses pour être détaillé.') }
    end
  end

  context 'with a condition on a champ gone from the form' do
    let(:public_type_de_champs) do
      [{ type: :text, libelle: 'Orphelin', mandatory: true, condition: ds_eq(champ_value(99), constant(true)) }]
    end

    it 'names the champ instead of its missing source' do
      rendered

      expect(page).to have_button('« Orphelin », dont la condition vise un champ absent du formulaire')
      expect(page).to have_text('Aucune réponse n’affiche le champ « Orphelin ».')
    end
  end
end
