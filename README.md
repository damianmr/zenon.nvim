# zenon

zenon centers text for writing in Neovim 0.12+. You enable it for a buffer. It
stays enabled when you change windows, open splits, or use a sidebar.

## Install

With lazy.nvim or LazyVim:

```lua
return {
  {
    "damianmr/zenon.nvim",
    main = "zenon",
    cmd = { "Zenon", "Zenoff" },
    opts = {},
  },
}
```

With Neovim's native package manager:

```lua
vim.pack.add({ "https://github.com/damianmr/zenon.nvim" })
require("zenon").setup({}) -- Optional with the default settings.
```

These examples use `main`. To use a fixed version, choose a published tag from
[Releases](https://github.com/damianmr/zenon.nvim/releases). Add `tag = "vX.Y.Z"`
to the lazy.nvim spec. With `vim.pack`, pass a table with `src` set to the URL
above and `version` set to that tag.

## Use

| Command | What it does |
| --- | --- |
| `:Zenon` | Enable the current buffer, or resize it with its current settings. |
| `:Zenon 60` | Use 60% of each split that shows the buffer. |
| `:Zenon 60 120 80` | Use 60%, with a maximum of 120 and a minimum of 80 text columns. |
| `:Zenoff` | Disable the current buffer. |
| `:Zenoff!` | Disable all enabled buffers. |

`:Zenon` never toggles off. The percentage includes the text window and its
margins. If there is too little room for the minimum width, zenon uses the width
available. Run `:Zenon` with another number to change the percentage.

## What to expect

Your file stays in its editing window. zenon adds blank windows as margins and
centers the text inside the split. If the buffer appears in several windows,
each window gets its own width. When you switch to another buffer, the first one
stays enabled. Its margins return when you switch back. You can open nvim-tree
or another sidebar without turning zenon off.

zenon wraps long lines on screen. In normal mode, `j` and `k` move by visible
rows. File contents, undo history, formatting, and spell checking stay the same.
On disable, zenon restores options and mappings that still match what it set.
It keeps changes you made later.

Margins are real windows. Commands such as `:windo` and window pickers can see
them. Filter `filetype=zenon-margin` in tools that should skip margins. With
several editing splits, zenon centers text inside each split. It does not keep
one selected buffer at the center of the whole Neovim screen.

## Configure

The defaults are 50% width and at least 80 text columns, with no maximum. For
example:

```lua
require("zenon").setup({
  width = 60,
  min_width = 80,
  max_width = 120,
  window_options = { spell = true },
})
```

zenon also has options for wrapping, margin dimming, navigation, and an optional
lualine adapter. It changes `ruler` while a buffer is enabled, but leaves
`showcmd` and statuslines alone. See [the help file](doc/zenon.txt) or
`:help zenon` for all options, Lua hooks, and the margin contract.

## Development and license

Run `make test` for headless Neovim tests and `make check` for formatting. zenon
uses the [MIT license](LICENSE) and has no required runtime dependencies.

## Compared with other plugins

### [zen-mode.nvim](https://github.com/folke/zen-mode.nvim)

- zenon stays enabled for a buffer when you use other splits or open nvim-tree.
  zen-mode.nvim opens one floating window. It closes when you enter a normal
  split.
- `:Zenon 60` sets the width from the command line. `:ZenMode` has no width
  argument. You can set its width in the config or through Lua.
- zen-mode.nvim can change terminal or GUI settings through its integrations.
  zenon leaves those settings alone. You can use hooks to change them yourself.

### [zen.nvim](https://github.com/sand4rt/zen.nvim)

- zenon is enabled per buffer. zen.nvim starts its layout after setup.
- zen.nvim centers one main buffer and can put sidebars around it. zenon centers
  text inside each editing split. With a sidebar open, zenon does not keep the
  file centered on the whole screen.
- Both allow splits. With several vertical splits, zen.nvim removes its
  centering margins. zenon keeps margins for enabled windows when space allows.
- zenon uses a percentage of each split, with optional minimum and maximum text
  widths. zen.nvim uses a main width in columns or a Lua function.
- zen.nvim can place sidebars by filetype on the left, right, top, or bottom.
  zenon leaves sidebar placement to you or the sidebar plugin.
