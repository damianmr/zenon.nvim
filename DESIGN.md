# zenon design

zenon keeps writing mode enabled for a buffer until `Zenoff`, `Zenoff!`, buffer
wipe, or editor exit. It requires Neovim 0.12+ and uses the MIT license.

## Buffers and windows

A session holds one buffer's options, runtime overrides, mappings, and cleanup
callback. A view holds one window's saved options and margin windows. The same
buffer can have a view in several windows or tabs.

Changing buffers restores the outgoing view's options. Returning to an enabled
buffer creates its view again. Focus changes and opening a sidebar keep the
buffer enabled.

## Margins and splits

The file stays in its native editing window. Blank scratch splits provide the
margins. Other windows stay visible. Margins use `buftype=nofile`,
`filetype=zenon-margin`, and `w:zenon_padding=true` so other plugins can find them.
See `:help zenon-margins` for the integration contract.

Layout changes temporarily disable automatic equalization and fix unrelated
window widths. They restore those options when done. Creating margins does not
enter them. Directional navigation skips margins immediately, so external
navigation plugins can find the next editing window. Window-cycle mappings also
skip margins. Before a normal quit, zenon removes the current view's margins.
If `:close` leaves only margins, zenon uses one to keep the file visible.

Margins are real splits. `:windo`, window pickers, and window counts include them.
Tools must filter them when needed. Separators use screen columns too. Small
gaps use one margin; a one-column gap can make the text one column narrower.

`WinNewPre` saves the source window's size and option baseline without changing
its layout. `WinNew` records the new window. After the native events finish,
zenon removes the old margins and shares their space between the new host
regions. Horizontal splits keep the full host width. This also handles several
splits before the scheduled update. Sidebars and later explicit resizes keep
their assigned sizes. Disabling restores the window options and keeps the
resulting native splits.

## Width

The host region includes the text window, its margins, and their separators.
`width` is a percentage of that region. `min_width` and `max_width` count text
columns after any retained gutters. Defaults are 50%, 80, and no maximum.

```text
available = host_window_columns + margin_columns + margin_separators
text_space = available - retained_gutters
cap = max_width or text_space
target = min(text_space, cap, max(min_width, floor(text_space * width / 100)))
```

An omitted or false maximum means no cap. False also clears an inherited cap.
Command arguments are percentage, maximum, minimum. The percentage must be finite
and in `(0, 100]`. Bounds must be positive integers, with minimum no greater than
maximum when set. Available space takes priority over the minimum. zenon validates
options before applying them and rolls back if Neovim rejects a value.

Window events share one scheduled update. Matching margin sizes are left alone
to avoid resize loops.

## Options and cleanup

The writing profile enables wrapping at word boundaries and indented
continuation rows. `showbreak` marks continuation rows. `scrolloff` sets the
scrolling context. These settings change how text looks on screen. File contents
and formatting stay unchanged. Spell checking stays as configured unless the
user sets `window_options.spell`.

Normal-mode `j` and `k` use visible rows, including counts. Operator-pending and
Visual mappings stay as configured. Existing buffer mappings take priority.
zenon removes only mappings that still point to its callbacks.

zenon saves raw local option values, including inheritance values. It restores
an option only if it still matches the value zenon applied. Margin highlights
follow the colorscheme and preserve transparent backgrounds. End-of-buffer
markers use local `fillchars`.

`ruler` is global. zenon saves it for the first enabled buffer and restores it
after the last one ends, unless the user changed it. Other global UI settings,
including `showcmd` and statuslines, stay as configured.

Setup and its rollback use the same configuration path. Enable failures restore
the old session or remove a new session. Cleanup continues after callback errors.
Hooks run per buffer; resize hooks describe the current windows. Hooks may read
state but cannot call lifecycle functions recursively.

## Integrations

The registry stores each adapter's callbacks, active state, and failure state in
one entry. Adapters can check availability, attach, update after layout changes,
and detach. Each callback gets its own context snapshot. An adapter stays active
while any enabled buffer requests it, including hidden buffers and other tabs.
A failed adapter waits until disable and re-enable before retrying. Other
adapters and editor cleanup continue.

The lualine adapter uses its public configuration API to exclude margins from
winbars and window statuslines. It restores only lists that still match what
zenon set. It keeps existing exclusions and later user changes. The core does
not load external plugins. See `:help zenon-integrations` for the callback API.

## Tests

`make test` uses isolated headless Neovim. Tests wait for scheduled work or an
expected result, compare split sizes with native Neovim, and restore fixtures
even after failures. Unexpected plugin warnings fail the test. CI tests the
supported Neovim versions on Ubuntu. Real plugins and a terminal are still
needed to check sidebar and tmux navigation.

## References

The ignored `ideas/` checkouts are behavior references, not dependencies. The
reviewed `folke/zen-mode.nvim` revision is
`8564ce6d29ec7554eb9df578efa882d33b3c23a7`. The reviewed `sand4rt/zen.nvim` revision
is `e1f0b3be2d78ec9d4386aefc86f03f17c4c41b29`. Useful ideas include native margins,
small-width handling, and testing tab and sidebar event order. A new window may
still show the source buffer during `WinNew`, before its destination buffer is
assigned. zenon waits for that event sequence before restoring inherited options.
Its per-buffer scope keeps existing side panels under their owners' control.
No reference code or tests were copied or adapted.
