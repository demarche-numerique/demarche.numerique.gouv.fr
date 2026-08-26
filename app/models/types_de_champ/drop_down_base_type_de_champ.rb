# frozen_string_literal: true

class TypesDeChamp::DropDownBaseTypeDeChamp < TypeDeChamp
  store_accessor :options, :drop_down_options

  def any_drop_down_list? = true
  # the editor offers the simple/advanced switch to the drop_down_list and the
  # multiple_drop_down_list only: the other lists are always simple
  def drop_down_mode = nil
  def drop_down_simple? = !drop_down_advanced?
  def drop_down_advanced? = false
  def drop_down_other? = false

  def revision_diff_options
    {
      drop_down_mode:,
      referentiel: drop_down_advanced? ? referentiel_id : nil,
      drop_down_options: drop_down_advanced? ? [] : drop_down_options,
      drop_down_other: drop_down_other?,
    }
  end

  def drop_down_options
    if drop_down_advanced?
      Array.wrap(referentiel&.drop_down_options)
    else
      Array.wrap(super)
    end
  end

  def drop_down_options=(options)
    super(Array.wrap(options).filter_map { _1.to_s.squish.presence })
  end

  def drop_down_options_from_text=(text)
    self.drop_down_options = text.to_s.lines
  end

  def options_for_select_with_other
    options = if drop_down_advanced?
      Array.wrap(referentiel&.options_for_select)
    else
      drop_down_options.uniq.map { [it, it] }
    end

    if drop_down_other?
      options << [I18n.t('shared.champs.drop_down_list.other'), Champs::DropDownListChamp::OTHER]
    end

    options
  end
end
