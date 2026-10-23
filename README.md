# `zenon.nvim`

`zenon.nvim` adds a zen mode to Neovim for reading and writing. It centers
text at a comfortable width and lets you move through wrapped lines as they
appear on screen. Enable it for a buffer, then open other files, splits, or a
sidebar. That buffer stays in zen mode when you return.

The same dummy note in a 120-column Neovim window:

| Without `zenon.nvim` | With `zenon.nvim` |
| --- | --- |
| ![Wide, unwrapped note](images/without-zenon.png) | ![Centered note with wrapped lines](images/with-zenon.png) |

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

Setup is optional. With `lazy.nvim` or `LazyVim`, put your changes in `opts`.
With other package managers, pass them to `require("zenon").setup()`.
You only need to include the options you want to change.

These are the defaults, with a quick explanation of each option:

```lua
require("zenon").setup({
  -- Percentage uses the split and its margins, minus retained gutters.
  width = 50,             -- Percentage, greater than 0 and at most 100.
  min_width = 80,
  max_width = nil,        -- Text columns; nil or false means no maximum.

  -- Wrapping and movement change the display, not the file contents.
  showbreak = "↪",       -- Marker on wrapped rows; false hides it.
  scrolloff = 10,         -- Rows of context above and below the cursor.
  breakindent = true,     -- Keep indentation on wrapped rows.
  wrap = true,           -- Wrap long lines on screen.
  linebreak = true,       -- Wrap at word boundaries.
  wrap_navigation = true, -- Normal-mode j/k move by visible rows, with counts.

  -- Appearance.
  hide_eob = true,        -- Hide ~ markers after the end of the buffer.
  dim = 0.15,             -- Darken margins: 0 to 1, or false to disable.
  ruler = false,          -- Hide Neovim's global cursor-position ruler.
  window_options = {
    number = false,       -- Hide line numbers.
    relativenumber = false,
    signcolumn = "no",     -- Hide the sign column.
    foldcolumn = "0",      -- Hide the fold column.
    list = false,         -- Hide whitespace markers.
    cursorline = false,   -- Hide cursor-line highlighting.
    cursorcolumn = false, -- Hide cursor-column highlighting.
  },

  integrations = {
    lualine = true,       -- Hide margin titles in an already loaded lualine.
  },
  hooks = {},            -- Optional callbacks, described below.
})
```

`min_width` and `max_width` count text columns. Both must be positive integers,
and a maximum must be at least the minimum. Available space takes priority
when a split is too narrow. `scrolloff` must be a nonnegative integer.

`window_options` accepts any window-local Neovim option and overrides the
corresponding display settings above. For example, use
`window_options = { spell = true, number = true }` to enable spell checking
and keep line numbers. Entries you omit keep their defaults. Window options
are restored when leaving a view; buffer mappings are restored
on disable. Later user changes are kept.

Existing buffer-local `j`/`k` mappings take priority over `wrap_navigation`.
Set it to `false` to keep your configured movement. `ruler` is global and is
restored after the last enabled buffer is disabled; `showcmd` and statuslines
stay as configured.

The `lualine` adapter hides margin winbars and window statuslines while keeping
file titles and the global statusline. It does not load `lualine` for you.
Set `integrations = { lualine = false }` to turn it off. Registered custom
adapters can also be enabled by name in this table.

Use `hooks` for custom behavior:

| Callback | When it runs |
| --- | --- |
| `on_enable = function(ctx) ... end` | Once per enabled buffer, after its views are created. May return a cleanup function that receives context when the session ends. |
| `on_disable = function(ctx) ... end` | After the buffer's session resources are removed. |
| `on_resize = function(ctx) ... end` | After a view is created or its geometry changes. |

Each callback receives `ctx.bufnr`, `ctx.reason`, `ctx.session_count`, and
`ctx.windows`. Each window entry has `winid`, `width`, and `available`.
The window list can be empty for hidden buffers or after disable. Hooks can
read state, but must not enable, disable, or reconfigure `zenon.nvim` inside
a callback.

For per-buffer overrides, use `require("zenon").enable({ width = 60 })`.
Use `{ max_width = false }` to clear an inherited maximum. Runtime overrides
take priority over setup defaults and are cleared on disable.

See [the help file](doc/zenon.txt) or `:help zenon` for the full Lua API,
custom adapter callbacks, and the margin contract.

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
