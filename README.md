# zenon

zenon centers text for writing in Neovim 0.12+. Other splits, sidebars, and tmux
panes stay usable. Enable it for a buffer; it stays enabled until `:Zenoff`,
buffer wipe, or editor exit.

zenon uses original Lua code and has no runtime dependencies.

## Install

With lazy.nvim, including LazyVim, add a plugin spec:

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

With Neovim 0.12's native package manager:

```lua
vim.pack.add({ "https://github.com/damianmr/zenon.nvim" })
require("zenon").setup({}) -- Optional when using defaults.
```

These examples follow `main`. To use a fixed version, choose an existing tag
from [Releases](https://github.com/damianmr/zenon.nvim/releases). Add
`tag = "vX.Y.Z"` to the lazy.nvim spec, replacing `vX.Y.Z` with that tag. For
`vim.pack`, use a table with `src = "https://github.com/damianmr/zenon.nvim"`
and `version = "vX.Y.Z"` instead of the URL string. Change the tag when you want
to upgrade.

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

The percentage uses the current text window and its margins. zenon recalculates
it when the terminal, sidebar, or split changes size. Minimum and maximum values
count text columns, excluding line numbers and other gutters you keep. Available
space takes priority over the minimum.

## Options

```lua
require("zenon").setup({
  width = 50,             -- Percentage of the current split, from >0 to 100.
  min_width = 80,         -- Minimum text columns, when there is enough room.
  max_width = nil,        -- No maximum; set a column count to limit width.
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
  integrations = { lualine = true },
  hooks = {},
})
```

Omit `max_width` for no maximum beyond the available space. To remove a maximum
inherited from setup or an earlier `enable` call, use
`require("zenon").enable({ max_width = false })`.

zenon dims the empty margins. Other buffers keep their colors and content.
Transparent themes stay transparent. Margin colors follow the colorscheme.

With `breakindent=true`, wrapped rows keep the original line's indentation.
These settings only change how text looks on screen. `showbreak` marks wrapped
continuation rows. It does not add spaces or newlines to the file.
Spell checking, indentation rules, `textwidth`, and formatting stay as configured.
You can set `window_options.spell = true` to enable spell checking in zenon.

## Navigation and scope

In enabled buffers, normal-mode `j` and `k` move through visible wrapped rows.
Counts use visible rows too: `5j` moves five rows down, and `5k` moves five rows
up, including within a wrapped paragraph. Operator-pending motions, such as `dj`,
and Visual-mode mappings are unchanged. Existing buffer mappings take priority.
Set `wrap_navigation=false` to keep your configured `j` and `k` behavior.

The file stays in its native editing split. zenon adds blank scratch windows
as left and right margins. Directional navigation skips them. Buffer mappings
for `Ctrl+w w`, `Ctrl+w Ctrl+w`, and `Ctrl+w W` cycle through editing windows.
Existing buffer mappings take priority. Tools can identify margins through
`vim.w[winid].zenon_padding`.

These are real split windows: commands such as `:windo` and third-party window
pickers can see them. Window pickers should exclude `buftype=nofile` or
`filetype=zenon-margin`. Very small margins may use one side only; with just one
spare column the text can be one column narrower than requested.

The lualine adapter excludes margins from winbars and window statuslines when
lualine is already loaded. It keeps file titles and the global statusline. When
the adapter stops, it restores exclusions that still match what zenon set and
keeps later user changes. Set `integrations = { lualine = false }` to manage
this yourself.

One enabled buffer can appear in several windows or tabs. Each window has its
own width and saved options. Splitting it shares the whole pane, including the
margins. Disabling keeps the resulting native splits. Changing to another buffer
restores the outgoing window's options; returning creates its margins again.
Leaving a split, changing tabs, or losing focus keeps the buffer enabled.

`ruler` is a global Neovim option. zenon saves it on the first enabled buffer and
restores it after the last is disabled or wiped. Use `ruler=true` if you want it
shown. If enabled buffers request different ruler values, hiding it takes
priority. `showcmd` and the editor's statusline settings are preserved. `showcmd`
displays partial commands and selection counts while you type.

zenon restores options and mappings only if they still match what it set. It
keeps later user changes. Global wrapping settings and movement mappings still
apply after disable. Remove those global settings if you want them only in zenon.

## Lua and hooks

```lua
local zenon = require("zenon")
zenon.enable({ width = 55, max_width = 120 })
zenon.disable()                     -- Current buffer.
zenon.disable_all()
zenon.is_enabled()                  -- Boolean, optionally accepts a buffer ID.
zenon.status()                      -- Enabled state and rendered window widths.
```

`enable(options, bufnr)` also accepts a buffer ID. You can repeat these calls.
`setup` replaces the defaults and updates active windows. Runtime buffer
overrides take priority.

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

Enable and disable hooks run once per buffer session. Resize hooks run after a
view is created or changes size. Focus changes do not repeat enable hooks. If an
enable hook fails, zenon removes the new session. It reports other hook errors
and continues cleanup. Hooks can read state but must not change zenon's state
from inside a callback. Use `session_count` for external state shared by buffers.

Twilight is a separate plugin that dims inactive text. Use hooks to configure
it or other behavior specific to your setup. zenon does not enable Twilight.

## Integrations

Adapters use a shared registry. zenon includes a
[lualine adapter](lua/zenon/integrations/lualine.lua). To add another adapter,
register it and enable it through the options:

```lua
local zenon = require("zenon")
local unregister = zenon.register_integration("my-bars", {
  available = function()
    return package.loaded["my-bars"] ~= nil
  end,
  attach = function(ctx)
    -- Prepare the plugin and return any state needed for updates or cleanup.
    -- Margins may not exist yet at this point.
    return {}
  end,
  update = function(ctx, state)
    for _, margin in ipairs(ctx.margins) do
      -- Configure this margin through your plugin's public API.
      -- margin: winid, bufnr, owner (editing window ID), side (left or right).
    end
  end,
  detach = function(ctx, state)
    -- Restore only state still owned by this integration.
  end,
})
zenon.setup({ integrations = { ["my-bars"] = true } })
-- unregister() removes the adapter and runs its cleanup, if attached.
```

An adapter attaches when an enabled buffer requests it and it is available.
`update` runs after layout changes. `detach` runs when no buffer requests it, it
becomes unavailable, or it is unregistered. Context lists enabled `buffers`,
editing `windows`, and `margins` across all tabs. Buffers share one attachment.
Without an `available` callback, zenon treats it as always available.

zenon checks availability on enable and scheduled window events. It does not
load other plugins or poll. Callback errors leave editing and other adapters
working. A failed adapter waits until disable and re-enable before retrying.

The margin identifiers are part of the integration contract:

| Identifier | Meaning |
| --- | --- |
| `require("zenon").is_margin(winid)` | Whether a window is a current zenon margin; defaults to the current window. |
| `vim.w[winid].zenon_padding == true` | Window marker for tools that do not require zenon. |
| `filetype=zenon-margin` | Identifies the scratch buffer, for plugin exclusion lists. |
| `buftype=nofile`, unlisted, nonmodifiable | The margin is display space and contains no user file. |

Two margins can share one scratch buffer. Their IDs can change. Use IDs from the
current context and check that they are valid before later work. Do not edit the
buffers or move, close, or reuse margin windows. zenon suppresses native creation
autocommands for margins; use `update` to find new windows. See
`:help zenon-integrations` and `:help zenon-margins` for the full API.

## Development

Local checks need Neovim 0.12+ (`nvim`) and StyLua (`stylua`) in your `PATH`.
On macOS, install them with Homebrew:

```sh
brew install neovim stylua
```

Run `make test` for isolated headless Neovim integration tests, `make check` for
StyLua checks, and `:checkhealth zenon` inside Neovim for basic diagnostics.
CI uses StyLua 2.6.0. See [DESIGN.md](DESIGN.md) for the layout and test design.

## Releases

Open **Actions > Release > Run workflow** on GitHub, select `main`, and enter
an unused version such as `v0.1.0`. You can add a short summary and upgrade
instructions to the generated release notes. Select **dry_run** to run the full
process without creating a tag or release.

The workflow runs the same tests and formatting checks as CI, then tags the
exact commit that passed and publishes a GitHub release. GitHub provides source
downloads; this Lua plugin needs no compiled release files. Published version
tags stay fixed. Fixes use a new version.

## License

MIT. See [LICENSE](LICENSE).
