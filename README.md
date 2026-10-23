# `zenon.nvim`

`zenon.nvim` adds a zen mode to Neovim for reading and writing. It centers
text at a comfortable width and lets you move through wrapped lines as they
appear on screen. Enable it for a buffer, then open other files, splits, or a
sidebar. That buffer stays in zen mode when you return.

## Install

Requires Neovim 0.12 or newer.

With `lazy.nvim` or `LazyVim`:

```lua
return {
  {
    "damianmr/zenon.nvim",
    tag = "v1.0.0",
    main = "zenon",
    cmd = { "Zenon", "Zenoff" },
    opts = {},
  },
}
```

With Neovim's native package manager:

```lua
vim.pack.add({
  { src = "https://github.com/damianmr/zenon.nvim", version = "v1.0.0" },
})
require("zenon").setup({}) -- Optional with the default settings.
```

Both examples install the published
[`v1.0.0` release](https://github.com/damianmr/zenon.nvim/releases/tag/v1.0.0).

## Use

| Command | What it does |
| --- | --- |
| `:Zenon` | Enable the current buffer, or resize it with its current settings. |
| `:Zenon 60` | Request 60% of each split that shows the buffer. |
| `:Zenon 60 80` | Request 60%, with a minimum of 80 text columns. |
| `:Zenon 60 80 120` | Request 60%, with a minimum of 80 and a maximum of 120 text columns. |
| `:Zenoff` | Disable the current buffer. |
| `:Zenoff!` | Disable all enabled buffers. |

The command order is percentage, minimum, maximum. The default is 50%, with a
minimum of 80 text columns and no maximum. With one split and no gutters:

| Split width | 50% | Text width |
| --- | ---: | ---: |
| 120 columns | 60 columns | about 80 columns |
| 200 columns | 100 columns | about 100 columns |

On a 120-column split, 50% is 60 columns, so the minimum makes the text about
80 columns wide. The percentage includes the text window and its margins.
Gutters, such as line numbers, can reduce the space for text. If the split is
too narrow for the minimum, `zenon.nvim` uses the width available. `:Zenon`
never toggles off.

## What to expect

Your file stays in its editing window. `zenon.nvim` adds blank windows as
margins and centers the text inside the split. If the buffer appears in several
windows, each window gets its own width. When you switch to another buffer,
the first one stays enabled. Its margins return when you switch back. You can
open `nvim-tree` or another sidebar without turning `zenon.nvim` off.

`zenon.nvim` wraps long lines on screen. In normal mode, `j` and `k` move by
visible rows. File contents, undo history, formatting, and spell checking stay
the same. On disable, `zenon.nvim` restores options and mappings that still
match what it set. It keeps changes you made later.

Margins are real windows. Commands such as `:windo` and window pickers can see
them. Filter `filetype=zenon-margin` in tools that should skip margins. With
several editing splits, `zenon.nvim` centers text inside each split. It does not
keep one selected buffer at the center of the whole Neovim screen.

## Configure

To change the defaults:

```lua
require("zenon").setup({
  width = 60,
  min_width = 80,
  max_width = 120,
  window_options = { spell = true },
})
```

`zenon.nvim` also has options for wrapping, margin dimming, navigation, and an
optional `lualine` adapter. It changes `ruler` while a buffer is enabled but
leaves `showcmd` and statuslines alone. See [the help file](doc/zenon.txt) or
`:help zenon` for all options, Lua hooks, and the margin contract.

## Development and license

Run `make test` for headless Neovim tests and `make check` for formatting.
`zenon.nvim` uses the [MIT license](LICENSE) and has no required runtime
dependencies.

## Compared with other plugins

### [`zen-mode.nvim`](https://github.com/folke/zen-mode.nvim)

- `zenon.nvim` stays enabled for a buffer when you use other splits or open
  `nvim-tree`.
  `zen-mode.nvim` opens one floating window. It closes when you enter a normal
  split.
- `:Zenon 60` sets the percentage from the command line. `:ZenMode` has no width
  argument. You can set its width in the config or through Lua.
- `zen-mode.nvim` can change terminal or GUI settings through its integrations.
  `zenon.nvim` leaves those settings alone. You can use hooks to change them yourself.

### [`zen.nvim`](https://github.com/sand4rt/zen.nvim)

- `zenon.nvim` is enabled per buffer. `zen.nvim` starts its layout after setup.
- `zen.nvim` centers one main buffer and can put sidebars around it.
  `zenon.nvim` centers text inside each editing split. With a sidebar open,
  `zenon.nvim` does not keep the file centered on the whole screen.
- Both allow splits. With several vertical splits, `zen.nvim` removes its
  centering margins. `zenon.nvim` keeps margins for enabled windows when space
  allows.
- `zenon.nvim` uses a percentage of each split, with optional minimum and
  maximum text widths. `zen.nvim` uses a main width in columns or a Lua function.
- `zen.nvim` can place sidebars by filetype on the left, right, top, or bottom.
  `zenon.nvim` leaves sidebar placement to you or the sidebar plugin.
