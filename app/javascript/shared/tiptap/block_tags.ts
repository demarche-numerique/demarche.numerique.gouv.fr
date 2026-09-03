import { Extension, type Editor } from '@tiptap/core';
import type { Node as PMNode, ResolvedPos } from '@tiptap/pm/model';
import { Plugin, PluginKey, type EditorState } from '@tiptap/pm/state';

// Some tags (repetition, multiple drop down, carte) render as a list. A list
// cannot live inside a title or a heading, so the server degrades such a tag to
// plain text there (TiptapService#to_html) and rejects it (TagsValidator). This
// module enforces the same rule in the editor.
const INLINE_ONLY_NODE_TYPES = ['title', 'heading'];

export function blockTagsAllowedAt($pos: ResolvedPos): boolean {
  for (let depth = $pos.depth; depth > 0; depth--) {
    if (INLINE_ONLY_NODE_TYPES.includes($pos.node(depth).type.name)) {
      return false;
    }
  }
  return true;
}

export function blockTagsAllowed(state: EditorState): boolean {
  return blockTagsAllowedAt(state.selection.$from);
}

// true when one of the text blocks covered by the selection holds a block tag
// (used to disable the heading buttons on such a paragraph).
export function selectionHoldsBlockTag(editor: Editor): boolean {
  const ids = blockTagIds(editor);
  if (ids.size == 0) {
    return false;
  }

  const { doc, selection } = editor.state;
  const { from, to, $from } = selection;
  const blocks: PMNode[] = [];

  if (from == to) {
    blocks.push($from.parent);
  } else {
    doc.nodesBetween(from, to, (node) => {
      if (node.isTextblock) {
        blocks.push(node);
        return false;
      }
      return true;
    });
  }

  return blocks.some((block) => {
    let found = false;
    block.forEach((child) => {
      if (isBlockTag(child, ids)) {
        found = true;
      }
    });
    return found;
  });
}

function blockTagIds(editor: Editor): Set<string> {
  return editor.storage.blockTagGuard?.ids ?? new Set<string>();
}

function isBlockTag(node: PMNode, ids: Set<string>): boolean {
  return node.type.name == 'mention' && ids.has(node.attrs.id);
}

export const BlockTagGuard = Extension.create<
  { blockTagIds: string[] },
  { ids: Set<string> }
>({
  name: 'blockTagGuard',

  addOptions() {
    return { blockTagIds: [] };
  },

  addStorage() {
    return { ids: new Set<string>() };
  },

  onBeforeCreate() {
    this.storage.ids = new Set(this.options.blockTagIds);
  },

  addProseMirrorPlugins() {
    const ids = this.storage.ids;

    return [
      new Plugin({
        key: new PluginKey('blockTagGuard'),

        // Reject any change that would leave a block tag inside a title or a
        // heading: turning the paragraph into a heading (button, shortcut or
        // "## " input rule), pasting, dropping…
        filterTransaction(tr) {
          if (!tr.docChanged) {
            return true;
          }

          let allowed = true;
          tr.doc.descendants((node, pos) => {
            if (allowed && isBlockTag(node, ids)) {
              allowed = blockTagsAllowedAt(tr.doc.resolve(pos));
            }
            return allowed;
          });
          return allowed;
        },

        // The renderer ignores marks on a block tag; strip them so the editor
        // does not pretend the list will be bold or italic.
        appendTransaction(transactions, _oldState, newState) {
          if (!transactions.some((tr) => tr.docChanged)) {
            return null;
          }

          const tr = newState.tr;
          newState.doc.descendants((node, pos) => {
            if (isBlockTag(node, ids)) {
              for (const mark of node.marks) {
                tr.removeMark(pos, pos + node.nodeSize, mark);
              }
            }
          });
          return tr.steps.length > 0 ? tr : null;
        }
      })
    ];
  }
});
