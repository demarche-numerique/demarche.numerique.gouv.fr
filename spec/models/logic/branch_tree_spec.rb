# frozen_string_literal: true

describe Logic::BranchTree do
  include Logic

  let(:situation) { build(:type_de_champ_drop_down_list, stable_id: 1, libelle: 'Situation', mandatory: true, drop_down_options: ['Salarié', 'Indépendant', 'Retraité']) }
  let(:age) { build(:type_de_champ_integer_number, stable_id: 2, libelle: 'Âge', mandatory: false) }
  let(:contrat) { build(:type_de_champ_text, stable_id: 3, libelle: 'Contrat', condition: ds_eq(champ_value(1), constant('Salarié'))) }
  let(:autorisation) { build(:type_de_champ_text, stable_id: 4, libelle: 'Autorisation', condition: ds_and([ds_eq(champ_value(1), constant('Salarié')), less_than(champ_value(2), constant(18))])) }
  let(:revenus) { build(:type_de_champ_text, stable_id: 5, libelle: 'Revenus', condition: ds_not_eq(champ_value(1), constant('Salarié'))) }

  let(:cluster) { Logic::Branches.new(type_de_champs).clusters.first }
  subject(:tree) { described_class.new(cluster) }

  def outline(node, depth = 0)
    if node.leaf?
      "#{'  ' * depth}→ #{node.visible.to_a.sort.join(', ').presence || 'rien'}"
    else
      node.children.map { |child| ["#{'  ' * depth}#{child.source.libelle} : #{child}", outline(child, depth + 1)] }.flatten
    end
  end

  context 'with one source' do
    let(:type_de_champs) { [situation, contrat, revenus] }

    it 'has a node per outcome, options merged' do
      expect(outline(tree.root)).to eq([
        'Situation : Salarié', '  → 3',
        'Situation : Indépendant, Retraité', '  → 5',
      ])
    end
  end

  context 'with nested sources' do
    let(:type_de_champs) { [situation, age, contrat, autorisation, revenus] }

    it 'nests in form order, merges identical subtrees and skips levels that do not branch' do
      expect(outline(tree.root)).to eq([
        'Situation : Salarié',
        '  Âge : 17 ou moins', '    → 3, 4',
        '  Âge : 18 ou plus, non renseigné', '    → 3',
        'Situation : Indépendant, Retraité', '  → 5',
      ])
    end

    it 'lists the leaves' do
      expect(tree.root.leaves.map(&:visible)).to eq([Set[3, 4], Set[3], Set[5]])
    end
  end

  context 'with a decimal source cut at a value' do
    let(:age) { build(:type_de_champ_decimal_number, stable_id: 2, libelle: 'Taux', mandatory: true) }
    let(:contrat) { build(:type_de_champ_text, stable_id: 3, libelle: 'Exact', condition: ds_eq(champ_value(2), constant(18))) }
    let(:revenus) { build(:type_de_champ_text, stable_id: 5, libelle: 'Plus', condition: greater_than(champ_value(2), constant(18))) }
    let(:type_de_champs) { [age, contrat, revenus] }

    it 'puts the value before what lies past it' do
      expect(outline(tree.root)).to eq(['Taux : moins de 18', '  → rien', 'Taux : 18', '  → 3', 'Taux : plus de 18', '  → 5'])
    end
  end

  context 'with an optional yes/no source' do
    let(:majeur) { build(:type_de_champ_yes_no, stable_id: 6, libelle: 'Majeur', mandatory: false) }
    let(:if_yes) { build(:type_de_champ_text, stable_id: 7, libelle: 'Oui', condition: ds_eq(champ_value(6), constant(true))) }
    let(:if_no) { build(:type_de_champ_text, stable_id: 8, libelle: 'Non', condition: ds_eq(champ_value(6), constant(false))) }
    let(:type_de_champs) { [majeur, if_yes, if_no] }

    it 'puts the blank answer last' do
      expect(outline(tree.root)).to eq(['Majeur : Oui', '  → 7', 'Majeur : Non', '  → 8', 'Majeur : non renseigné', '  → rien'])
    end
  end

  context 'with answers merged across an interval' do
    let(:age) { build(:type_de_champ_integer_number, stable_id: 2, libelle: 'Âge', mandatory: true) }
    let(:actif) { build(:type_de_champ_text, stable_id: 3, libelle: 'Actif', condition: ds_and([greater_than_eq(champ_value(2), constant(18)), less_than_eq(champ_value(2), constant(65))])) }
    let(:type_de_champs) { [age, actif] }

    it 'joins the intervals into one answer' do
      expect(outline(tree.root)).to eq(['Âge : 17 ou moins ou 66 ou plus', '  → rien', 'Âge : de 18 à 65', '  → 3'])
    end
  end

  context 'with answers merged across departements' do
    let(:lieu) { build(:type_de_champ_departements, stable_id: 2, libelle: 'Lieu', mandatory: true) }
    let(:aide) { build(:type_de_champ_text, stable_id: 3, libelle: 'Aide', condition: ds_or([ds_in_region(champ_value(2), constant('84')), ds_eq(champ_value(2), constant('75'))])) }
    let(:type_de_champs) { [lieu, aide] }

    it 'joins the departements into one answer' do
      expect(outline(tree.root)).to eq(['Lieu : Auvergne-Rhône-Alpes, 75 – Paris', '  → 3', "Lieu : #{lieu.condition_options.size - 13} départements", '  → rien'])
    end
  end

  context 'with a first source that changes nothing' do
    let(:toujours) { build(:type_de_champ_text, stable_id: 6, libelle: 'Toujours', condition: ds_or([ds_eq(champ_value(1), constant('Salarié')), ds_not_eq(champ_value(1), constant('Salarié')), less_than(champ_value(2), constant(0))])) }
    let(:mineur) { build(:type_de_champ_text, stable_id: 7, libelle: 'Mineur', condition: less_than(champ_value(2), constant(18))) }
    let(:type_de_champs) { [situation, age, toujours, mineur] }

    it 'starts at the next source' do
      expect(outline(tree.root)).to eq(['Âge : 17 ou moins', '  → 6, 7', 'Âge : 18 ou plus, non renseigné', '  → 6'])
    end

    context 'and no other source' do
      let(:type_de_champs) { [situation, toujours] }

      it 'is a single leaf' do
        expect(tree.root).to be_leaf
        expect(tree.root.visible).to eq(Set[6])
      end
    end
  end

  context 'with a source that changes nothing' do
    let(:type_de_champs) { [situation, age, revenus] }

    it 'is a single leaf per outcome, no level for it' do
      expect(outline(tree.root)).to eq(['Situation : Salarié', '  → rien', 'Situation : Indépendant, Retraité', '  → 5'])
    end
  end

  context 'with merged answers that list values themselves' do
    let(:options) { build(:type_de_champ_multiple_drop_down_list, stable_id: 7, libelle: 'Options', mandatory: true, drop_down_options: ['A', 'B', 'C']) }
    let(:any) { build(:type_de_champ_text, stable_id: 8, libelle: 'Une', condition: ds_or([ds_include(champ_value(7), constant('A')), ds_include(champ_value(7), constant('B'))])) }
    let(:type_de_champs) { [options, any] }

    it 'tells the answers apart from the values' do
      expect(outline(tree.root)).to eq(['Options : sans A, B', '  → rien', 'Options : avec A ou avec B, sans A', '  → 8'])
    end
  end

  context 'with a member no branch displays' do
    let(:dead) { build(:type_de_champ_text, stable_id: 6, libelle: 'Jamais', condition: ds_and([ds_eq(champ_value(1), constant('Salarié')), ds_eq(champ_value(1), constant('Retraité'))])) }
    let(:type_de_champs) { [situation, contrat, dead] }

    it { expect(tree.never_displayed).to eq([dead]) }
  end

  context 'with more leaves than can be read' do
    let(:type_de_champs) { [situation, age, contrat, autorisation, revenus] }

    before { stub_const('Logic::BranchTree::MAX_LEAVES', 2) }

    it 'is capped, but still knows what is never displayed' do
      expect(tree).to be_capped
      expect(tree.root).to be_nil
      expect(tree.never_displayed).to be_empty
    end
  end

  context 'with a capped cluster' do
    let(:type_de_champs) { [situation, contrat] }

    before { stub_const('Logic::Branches::MAX_BRANCHES', 1) }

    it do
      expect(tree).to be_capped
      expect(tree.root).to be_nil
      expect(tree.never_displayed).to be_empty
    end
  end
end
