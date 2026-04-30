# frozen_string_literal: true

class ProcedurePath < ApplicationRecord
  PATH_REGEX = /\A[a-z0-9\-_]{2,199}[a-z0-9]\z/
  PATH_HTML_PATTERN = '[a-z0-9\-_]{2,199}[a-z0-9]'

  belongs_to :procedure

  before_destroy :ensure_one_path, :ensure_is_customized

  normalizes :path, with: -> path { path.strip.downcase }

  validates :path, presence: true, format: { with: PATH_REGEX, if: -> { new_record? || path_changed? } }, uniqueness: true

  def ensure_one_path
    return if procedure.procedure_paths.count > 1 || destroyed_by_association

    errors.add(:base, :at_least_one_path)
    throw(:abort)
  end

  def ensure_is_customized
    return if !uuid_path? || destroyed_by_association

    errors.add(:base, :cannot_delete_customized_path)
    throw(:abort)
  end

  def uuid_path?
    path.match?(/[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}/)
  end
end
