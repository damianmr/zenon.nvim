# zenon

A writing mode for Neovim 0.12+. Center text inside its current split while
other splits, sidebars, and tmux panes remain usable. Enabled state belongs to
buffers and stays active until `:Zenoff`, buffer wipe, or editor exit.

zenon uses original Lua code and has no runtime dependencies.

## Install

With lazy.nvim, including LazyVim, add a plugin spec:

```lua
return {
  {
    "damianmr/zenon",
    main = "zenon",
    cmd = { "Zenon", "Zenoff" },
    opts = {},
  },
}
```

With Neovim 0.12's native package manager:

```lua
vim.pack.add({ "https://github.com/damianmr/zenon" })
require("zenon").setup({}) -- Optional when using defaults.
```

## Commands

| Command | Effect |
| --- | --- |
| `:Zenon` | Enable the current buffer using its current or configured values. |
| `:Zenoff` | Disable the current buffer and restore its views. |
| `:Zenon 50` | Enable or resize to 50% of each host split. |
| `:Zenon 50 1000` | Also set a maximum of 1000 text columns. |
| `:Zenon 50 1000 200` | Also set a minimum of 200 text columns. |
| `:Zenoff!` | Disable every enabled buffer. |

`Zenon` always enables; repeating it never toggles the mode off. Width arguments
are percentage, maximum, minimum, in that order. Omitted arguments keep the
buffer's existing overrides or use setup defaults. Disabling clears its runtime
overrides.

The percentage is based on the space owned by that buffer's view: the text
window plus its margins. It is recalculated when the terminal, sidebar, or split
changes size. Minimum and maximum values count text columns, excluding retained
gutters. Available space wins when the split is narrower than the minimum.

## Options

```lua
require("zenon").setup({
  width = 50,             -- Percentage of the current split, from >0 to 100.
  min_width = 80,         -- Minimum text columns, when there is enough room.
  max_width = 160,        -- Maximum text columns.
  showbreak = "↪",       -- Wrapped continuation marker; false disables it.
  scrolloff = 10,         -- Screen rows of context above and below the cursor.
  breakindent = true,     -- Continue wrapped rows at the line's indentation.
  wrap = true,
  linebreak = true,       -- Prefer wrapping at word boundaries.
  wrap_navigation = true,
  hide_eob = true,        -- Hide ~ markers after the final file line.
  dim = 0.15,            -- Darken empty margins by this amount; false disables.
  ruler = false,         -- Global option; see the scope notes below.
  window_options = {
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    list = false,
    cursorline = false,
    cursorcolumn = false,
  },
  hooks = {},
})
```

Only the empty margins are dimmed. Other buffers keep their colors and content.
Transparent themes stay transparent. Custom margins follow colorscheme changes.

With `breakindent=true`, an indented file line that wraps continues at the same
visual indentation. It changes display, not spaces or newlines in the file.
`showbreak` marks these continuation rows, rather than actual newline characters.
Spell checking, indentation rules, `textwidth`, and formatting stay as configured.
You can set `window_options.spell = true` to enable spell checking in zenon.

## Navigation and scope

In enabled buffers, normal-mode `j` and `k` move through visible wrapped rows.
Counted moves such as `5j` keep their normal file-line meaning. `5gj` moves five
visible rows. Operator-pending motions, such as `dj`, and Visual-mode mappings
are unchanged. Existing buffer-local mappings take priority. Set
`wrap_navigation=false` to leave `j` and `k` entirely as configured.

The text buffer remains in a native editing split. zenon adds unlisted scratch
windows as left and right margins. Directional window navigation skips these
margins; buffer-local `Ctrl+w w`, `Ctrl+w Ctrl+w`, and `Ctrl+w W` cycle through
editing windows. Existing buffer-local mappings are preserved. Margins are
identified by `vim.w[winid].zenon_padding` for window pickers and other tools.

These are real split windows: commands such as `:windo` and third-party window
pickers can see them. Window pickers should exclude `buftype=nofile` or
`filetype=zenon-margin`. Very small margins may use one side only; with just one
spare column the text can be one column narrower than requested.

One enabled buffer can appear in multiple windows. Each view gets its own width
and saved window options. Changing to an unrelated buffer restores the old view;
returning to the enabled buffer recreates it. Leaving a split, changing tabs,
or losing application focus does not disable the buffer.

`ruler` is a global Neovim option. zenon saves it on the first enabled buffer and
restores it after the last is disabled or wiped. Use `ruler=true` if you want it
shown. If enabled buffers request different ruler values, hiding it takes
priority. `showcmd` and the editor's statusline settings are preserved. `showcmd`
displays partial commands and selection counts while you type.

Changed options and mappings are restored only while they still match what
zenon installed, preserving later user changes. If your personal configuration
already sets global wrapped-row mappings or wrapping, removing those settings
is necessary if you want that behavior exclusively inside zenon.

## Lua and hooks

```lua
local zenon = require("zenon")
zenon.enable({ width = 55, max_width = 120 })
zenon.disable()                     -- Current buffer.
zenon.disable_all()
zenon.is_enabled()                  -- Boolean, optionally accepts a buffer ID.
zenon.status()                      -- Enabled state and rendered window widths.
```

`enable(options, bufnr)` also accepts a buffer ID. All lifecycle functions are
safe to repeat. `setup` replaces setup defaults and updates active views;
per-buffer runtime overrides still take priority.

```lua
require("zenon").setup({
  hooks = {
    on_enable = function(ctx)
      -- ctx: bufnr, reason, session_count, windows.
      -- Each window: winid, width, available.
      -- Return optional cleanup for this buffer's session.
      return function(closing_ctx)
        -- Restore your custom integration here.
      end
    end,
    on_disable = function(ctx) end,
    on_resize = function(ctx) end,
  },
})
```

Enable and disable hooks run per buffer. Resize hooks run after a view is created
or its dimensions change. Focus changes do not repeat enable hooks. An enable
hook failure rolls back the new session. Cleanup and other hook errors are
reported while resource cleanup continues. Hooks may inspect state but must not
call lifecycle functions recursively. External integrations should use
`session_count` to coordinate state shared across buffers.

Twilight is an optional separate plugin that dims inactive regions of text.
zenon does not enable it. Use hooks for Twilight or environment-specific behavior.

## Development

Run `make test` for isolated headless Neovim integration tests, `make check` for
StyLua checks, and `:checkhealth zenon` inside Neovim for basic diagnostics.
StyLua 2.6.0 is used in CI. See [DESIGN.md](DESIGN.md) for layout decisions and
[FEATURES.md](FEATURES.md) for the requirements.

## License

MIT. See [LICENSE](LICENSE).
