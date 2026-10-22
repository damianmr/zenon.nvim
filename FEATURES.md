# zenon requirements

- Implement zenon with original Lua code. Other plugins may inform editor
  settings and behavior, but their implementation must not be copied.
- Work per buffer. Other splits and sidebars remain visible and usable.
- Stay enabled across split, tab, and application focus changes until explicitly
  disabled, the buffer is wiped, or Neovim exits.
- Provide `Zenon`, `Zenoff`, `Zenon 50`, `Zenon 50 1000`, and
  `Zenon 50 1000 200`. `Zenon` enables or resizes; `Zenoff` disables.
- Interpret width as a percentage of the current pane, with configurable minimum
  and maximum text columns. Fit available space when it is below the minimum.
- Make the wrapped continuation marker configurable as a string or disabled.
- Make scrolling context and indented continuation rows configurable.
- Provide comfortable wrapped-row navigation, word-boundary wrapping, a dim
  background around the text, hidden end-of-buffer markers, and a disabled ruler.
- Normal-mode `j` and `k`, including counts such as `5j` and `5k`, move through
  visible screen rows.
- Preserve partial command display (`showcmd`) and ordinary statuslines.
- Allow nvim-tree to open and close without disabling enabled buffers.
- Keep tmux, terminal, GUI, and other plugin integrations out of the core. Provide
  lifecycle hooks for user-defined integrations.
- Support LazyVim through lazy.nvim and native Neovim packages, including
  `vim.pack` in Neovim 0.12.
- Restore changed options and mappings while preserving later user changes.
- Publish under MIT, selected by the owner.
