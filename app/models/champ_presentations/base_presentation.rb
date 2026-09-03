# frozen_string_literal: true

module ChampPresentations
  class BasePresentation
    # Nodes of the tiptap schema standing for the value where it is mentioned:
    # block nodes replace the enclosing paragraph, inline nodes stay in it.
    def to_tiptap_nodes = [to_tiptap_node]
  end
end
