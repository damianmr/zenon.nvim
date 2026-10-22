# zenon design

zenon is an original implementation of a writing mode that stays active per
buffer. Neovim 0.12 is the minimum supported version. The MIT license applies.

## Buffer sessions and window views

A session stores one buffer's enabled state, configuration overrides, mappings,
and hook cleanup. A separate view stores each window's previous options and its
margin windows. Showing the same enabled buffer in two windows creates two
independent views.

Only `Zenoff`, `Zenoff!`, buffer wipe, or editor exit removes session intent.
Leaving a window, losing terminal focus, changing tabs, and opening a sidebar
retain it. Replacing a buffer in a window removes that view and restores its
options. Returning to the enabled buffer recreates the view.

## Native margin layout

The user's buffer stays in its original native editing window. Blank, unlisted
scratch splits provide margins. No editor-wide overlay hides other splits.
The margins use `buftype=nofile`, `filetype=zenon-margin`, and the window variable
`zenon_padding=true` so integrations can identify them.

Layout transactions temporarily disable automatic equalization and fix unrelated
window widths, then restore those options. Margin creation does not enter the
new windows. Directional navigation skips margins synchronously, allowing an
external navigator to detect when there is no further Neovim editing window.
Window-cycle mappings skip margins in enabled buffers. Before quitting, margins
are removed so ordinary last-window quit behavior remains available.

Native margins remain visible to `:windo`, window pickers, and window counts.
This is the main layout tradeoff. Integrations should filter scratch windows.
One or two separators also consume columns. When little margin space remains,
use a single margin; a one-column gap can make the text one column narrower.

Before a native split, `WinNewPre` records the source view's geometry without
changing the layout. `WinNew` records the new window and its inherited option
baseline. Once events settle, zenon removes the old margins and shares their
space between the new host regions before rebuilding margins. Horizontal
splits retain the full host width. Multiple splits before reconciliation are
tracked together. Sidebars and explicit size changes made after `WinNew` keep
their geometry. Turning zenon off restores the editing options in all views
and leaves the resulting native split widths in place.

## Width

`width` is a percentage of the host region. `min_width` and `max_width` count text
columns. Defaults are 50%, 80, and no maximum. An omitted or false `max_width`
means no cap beyond available space. Explicit false overrides an inherited cap.
Command arguments are percentage, maximum, minimum. `Zenon` enables or resizes
and never toggles off.

```text
available = host_window_columns + margin_columns + margin_separators
text_space = available - retained_gutters
cap = max_width or text_space
target = min(text_space, cap, max(min_width, floor(text_space * width / 100)))
```

Numeric bounds must be positive integers with minimum no greater than maximum
when a maximum is set. The percentage must be finite and in `(0, 100]`.
Insufficient available space takes priority over the minimum. Invalid input is
rejected before changing state.

Resize events are coalesced through a scheduled reconciliation pass. Geometry
is left alone when the desired margin sizes already match. This avoids loops
caused by the plugin's own resize events.

## Writing settings

The default writing profile enables soft wrapping, word-boundary wrapping, and
indented continuation rows. `showbreak` is a string or false; it is not a marker
for actual newline characters. `scrolloff` controls scrolling context.

Normal-mode `j` and `k` use screen rows with or without a count. `5j` moves five
visible rows down and `5k` moves five visible rows up. Operator-pending and
Visual-mode mappings stay unchanged. Existing buffer-local mappings take
precedence. Newly installed mappings are removed only if they still point to
zenon's callback.

Options use window scope, with their local inheritance values saved for
restoration. Existing formatting, spell checking, and buffer contents are
preserved. End-of-buffer markers are hidden through the local `fillchars` option.
Colorscheme-aware margin highlighting dims the empty margins without changing
other buffers. Transparent backgrounds are preserved.

`ruler` is necessarily global. It is saved once for the first enabled buffer and
restored after the final session ends. Later user changes survive restoration.
`showcmd`, statuslines, and unrelated global UI settings are preserved.

## Hooks and errors

Enable and disable hooks run per buffer; resize hooks describe view geometry.
The enable hook may return a cleanup function. Context includes buffer ID,
session count, transition reason, and visible view widths. Focus changes do not
repeat enable hooks. Reentrant lifecycle changes are rejected.

Failed initialization restores options and removes owned windows. A failed
reconfiguration restores the previous session. Cleanup errors are reported and
must not prevent other resources from being cleaned up.

## Optional integrations

The session and layout code use a shared adapter registry. Each integration
can check availability, attach once, update after layout reconciliation, and
detach with its saved state. An adapter stays active while any enabled buffer
requests it, including across hidden buffers and multiple tabs. Failures are
isolated from editing and other adapters. No external plugin is force-loaded.

The first adapter is lualine. It adds the margin filetype to lualine's public
exclusion settings and restores only lists that still match its applied values.
It keeps existing entries and later user changes. Plugin-specific behavior lives
in lua/zenon/integrations/, with the public callback and margin contracts
documented in :help zenon-integrations and :help zenon-margins.

## Verification

`make test` exercises the public commands, real native windows, buffer lifecycles,
wrapped-row motions, configuration validation, restoration, and hook failure
handling in an isolated Neovim process. CI runs supported Neovim releases on
Ubuntu. Sidebar and terminal navigation also need real-plugin and TUI
checks because a headless test alone does not establish tmux behavior.

No source from the reference plugin is copied or adapted. The implementation
uses documented Neovim APIs and no required external plugins or programs.

## Review of zen.nvim

The local `sand4rt/zen.nvim` reference was reviewed at revision
`e1f0b3be2d78ec9d4386aefc86f03f17c4c41b29`. Useful behavior ideas include
native margins, avoiding unnecessary layout changes, handling small widths,
and testing tab and sidebar event ordering. In particular, `WinNew` can still
show the source buffer before the destination buffer is assigned. zenon saves
inherited option baselines, then reconciles after the event sequence settles,
so an unrelated new split does not retain the writing profile.

Its global side-panel placement and replacement policy does not fit zenon's
per-buffer scope. zenon keeps existing panels under their owners' control and
does not close margins simply because another editing split appears. A width
callback could be useful later, but percentage plus bounds covers the current
requirements. No code or test implementation was copied from the reference.
