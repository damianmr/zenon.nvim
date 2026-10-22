# zenon design review

zenon should make writing comfortable while other splits and tools remain
usable. The main engineering risk is maintaining a centered text area without
breaking normal window navigation. Prove that layout behavior before building
integrations or a large configuration surface.

The requirements in `FEATURES.md` are the starting point. Behaviors described
as proposals below are open for discussion.

## Confirmed goals

- Use the name zenon and implement it from the requirements with original code.
  The reference plugin may inform editor settings and behavior; its implementation
  must not be copied, translated, or mechanically adapted.
- Default to 50% width, with configurable minimum and maximum bounds and runtime
  changes. The current personal configuration uses 45%; the requested new
  default is 50%.
- Keep zen mode active when changing focus, including moving to a tmux pane.
- Associate zen mode with buffers and leave other splits usable.
- Allow nvim-tree to open and close while zen mode remains active.
- Keep tmux, terminal, GUI, and plugin integrations outside the core, using hooks.
- Support LazyVim and native Neovim packages, including `vim.pack` in 0.12.

## What upstream actually does

The reviewed [zen-mode.nvim revision](https://github.com/folke/zen-mode.nvim/tree/8564ce6d29ec7554eb9df578efa882d33b3c23a7)
opens the current buffer in an editor-relative floating window above a full
editor backdrop. Existing splits stay underneath it. Entering another normal
window schedules zen mode to close after 10 milliseconds.

A headless check on Neovim 0.12.2 reproduced that closure by entering another
normal split, without tmux. This explains a likely path for the reported
Ctrl+h/j/k/l behavior. The exact keypress path still needs checking with the
active navigator configuration; it is not evidence that terminal focus loss
alone closes zen mode.

The actual defaults in the checked-in Lua source are:

- A 120-column zen window, full available editor height, and a dim backdrop.
- `ruler=false` and `showcmd=false` while active, restored on close. These are
  global changes.
- Twilight is attempted if available. Other integrations are disabled by default.
- The cursor is vertically centered once on entry with `zz`.
- Highlight and fill-character changes hide end-of-buffer markers and borders.
- The editing float has no ordinary split statusline. The source does not set
  `laststatus` by default, although the README's example includes `laststatus=0`.

The user's current zen-mode configuration adds `signcolumn="no"`, `number=false`,
`relativenumber=false`, `cursorline=false`, `cursorcolumn=false`, `foldcolumn="0"`,
and `list=false`. It disables Twilight and uses `width=0.45`.

Neither that configuration nor upstream changes `j`/`k` mappings, `wrap`,
`linebreak`, `breakindent`, `spell`, or `textwidth`. A narrower text area can
change wrapping without changing navigation settings. Explicit writing behavior
needs a separate choice.

The broader personal Neovim configuration already maps plain `j` and `k` to
`gj` and `gk`, while preserving file-line movement when a count is supplied.
It also sets `linebreak`, `breakindent`, `showbreak="↪"`, and `scrolloff=10`.
An autocmd enables wrapping and spell checking for Markdown, text, and commit
messages. Those settings come from the user's configuration, outside zen-mode.

## Buffer intent and window layout

Neovim displays a buffer through one or more windows. Width, wrapping, cursor,
and scroll position belong to a window, so a buffer-only state table cannot
represent the complete layout.

Proposed model: remember enabled state and width preferences per buffer, and
manage layout and saved window options per visible window. Showing the same
enabled buffer in two splits creates two independently sized views. An unrelated
buffer keeps its ordinary view. Switching back to an enabled buffer restores
its zen view. Disabling that buffer disables all its zen views.

Keep this state within the current Neovim process for the first version.
Wiping the buffer clears its state. Cross-restart persistence can be added later
if there is a concrete need.

The key unresolved choice is whether zen mode should follow the buffer or stay
attached to a split when that split changes buffers. Following the buffer best
matches the original requirement.

## Width and centering

Centering within the buffer's current split best preserves other splits.
Centering over the whole editor can overlap a sidebar or another split.

The original request says percentage of the terminal. Preserve that meaning as
the proposed width basis: take the percentage of Neovim's total columns, then
limit it to the host split's available area. The centering anchor and the width
basis are separate choices. A percentage of the host split could be an optional
basis if desired.

Proposed calculation:

```text
target = floor(editor_columns * percentage / 100)
bounded = max(minimum, min(maximum, target))
text_columns = max(1, min(available_host_columns, bounded))
```

Widths are screen cells, not pixels or bytes. Measure the text area after any
retained gutters or borders. Available space wins when the terminal or split is
narrower than the requested minimum; keep zen intent active and remove margins
as necessary. Recompute after terminal resizing, split resizing, or sidebar
changes.

For example, with a 240-column editor, a 180-column host split, and
`55 600 120`, the text area is 132 columns. In a 100-column host it is capped
at 100 columns. On a 160-column editor with enough host space it is raised to
120 columns by the minimum.

The examples supply a minimum of 120 and a maximum of 600, but do not establish
the defaults. Choose those values before implementing the first release.

Reject percentages outside `(0, 100]`, nonfinite values, noninteger or nonpositive
bounds, and `minimum > maximum`. Do not change state on invalid input.

## Commands and configuration

Neovim [requires user commands to start with a capital letter](https://github.com/neovim/neovim/blob/v0.12.6/runtime/doc/map.txt).
Use `:Zenon`, with a lowercase Lua module named `zenon`.

Proposed command behavior preserves the requested argument order:

| Command | Behavior |
| --- | --- |
| `:Zenon` | Toggle the current buffer, keeping its last width values. |
| `:Zenon 55` | Enable or resize with 55%; preserve the buffer's other values. |
| `:Zenon 55 600` | Also set the maximum to 600 columns. |
| `:Zenon 55 600 120` | Also set the minimum to 120 columns. |

For a buffer with no previous overrides, omitted values come from setup defaults.
Arguments resize an active view instead of toggling it off. Runtime overrides
apply to that buffer, without rewriting setup defaults or configuration files.

Expose Lua `setup`, `enable`, `disable`, `toggle`, `resize`, and `is_enabled`
functions. Enable and disable should be safe to call repeatedly. Setup should be
optional for default behavior and repeatable without accumulating handlers.
The exact public option names remain to be settled.

## Editing behavior and restoration

Use the user's current hidden-gutter and cursor-highlight settings as the
proposed default appearance. Preserve wrapping, spell checking, text width,
indentation, and keymaps unless the user explicitly configures changes.

An optional writing profile could enable soft wrapping, word-boundary wrapping
with `linebreak`, and wrapped indentation with `breakindent`. Spell checking
needs a language choice. Mapping `j` and `k` to visual lines changes navigation
and macros; it should be an explicit option. Do not change hard wrapping or
formatting rules implicitly.

### Wrapped text navigation proposal

A file line can occupy several screen rows. Native `j` and `k` move through
file lines; `gj` and `gk` move through screen rows. For writing, propose the
same count-aware behavior already present in the user's configuration:

| Input | Proposed behavior while zenon is enabled |
| --- | --- |
| `j` / `k` | Move one visible row down / up. |
| `5j` / `5k` | Preserve movement through five file lines. |
| `5gj` / `5gk` | Move through five visible rows using native motions. |
| `g0` / `g^` / `g$` | Native start / first nonblank / end of the visible row. |

Keep `0`, `^`, and `$` unchanged for navigating the complete file line. Preserve
operator-pending mappings so commands such as `dj` retain their linewise meaning.
Visual selection behavior, arrow keys, and Insert-mode navigation need separate
choices. Do not silently overwrite user-defined buffer mappings. Any zenon
mapping must respect its buffer scope and restore previous mappings on disable.

Propose `wrap=true`, `linebreak=true`, and `breakindent=true` as a configurable
writing profile. These change display rather than inserting newlines into the
file. Preserve the user's continuation marker or make it configurable. A modest
`scrolloff`, such as 5 to 10 rows, keeps surrounding context visible.
`smoothscroll` is an optional screen-row scrolling setting, rather than an
animation; verify its limitations on supported Neovim versions before making
it a default. Keep `textwidth` and formatting rules unchanged.

These are proposals, not implemented or approved defaults. See Neovim's
[motion reference](https://neovim.io/doc/user/motion/) and
[option reference](https://neovim.io/doc/user/options/).

Global options such as `ruler`, `showcmd`, and `laststatus` affect other splits.
Keep global UI changes opt-in. If enabled with multiple zen views, save once and
restore when the final view closes. For each option, restore the previous value
only when its current value still matches what zenon applied, so later user
changes survive.

Apply and restore window options per window and buffer association. Preserve
cursor position, scroll position, folds, unsaved changes, and undo history.
Never close or wipe the user's buffer as part of layout cleanup.

## Layout prototype

A full editor overlay would obscure other windows and conflict with the split
and sidebar requirements. The original implementation should confine the zen
layout to the host split.

Prototype a layout confined to the host split and compare it with native padding
splits. A float can preserve surrounding split geometry, but creates challenges
for native window navigation, mouse input, file pickers, and buffer replacement.
Padding splits participate in navigation and can cause Neovim to rebalance other
splits. Neither approach should be accepted without a working interaction check.

The prototype must show two ordinary splits, one zen buffer, and a sidebar.
Verify native Ctrl+w navigation and user-provided tmux navigation without adding
tmux code or replacing Ctrl+h/j/k/l mappings in the core. If the available
Neovim layout mechanisms require a compromise, decide it with a visible example.

Opening nvim-tree necessarily uses some editor space. The useful requirement is
that zen stays enabled, fits its new host area, and keeps its preferences. The
core must not initiate unrelated resizing, focus jumps, or layout restoration.
If nvim-tree opens a different buffer in the host, apply the chosen buffer
lifecycle rule rather than inheriting zen state accidentally.

## Hooks and lifecycle

Offer callbacks for enable, disable, and resize, with a context containing buffer
and window IDs, requested width, actual width, and the transition reason.
Document whether each callback runs per buffer or per rendered window. A buffer
enable hook can return cleanup work for its matching disable hook.

Handle callback failures visibly and continue resource cleanup. Roll back partial
initialization. Do not fire enable and disable hooks again just because focus
changed or the editor resized. Hooks that change global external state need to
account for multiple enabled buffers; provide a session count or first/last
session events to make that possible.

Exclude terminal, prompt, quickfix, help, and sidebar buffers by default, using
generic buffer eligibility and an overridable predicate. Support unnamed normal
buffers. Handle buffer replacement, buffer wipe, window close, tab changes,
colorscheme changes, and editor exit without stale windows or autocommands.

## Compatibility and maintenance

Prefer a small Lua core with no runtime dependencies. Support the standard
`lua/`, `plugin/`, and `doc/` layout and public Neovim APIs. Keep configuration,
width calculation, rendering, and state management separate. Avoid plugin
internals and automatic environment detection.

Neovim 0.12 is a reasonable initial support target because it is the requested
environment. Supporting earlier versions is a separate maintenance decision.
Native package management does not require a plugin dependency:
[vim.pack documentation](https://github.com/neovim/neovim/blob/v0.12.6/runtime/doc/pack.txt).
The local review used Neovim 0.12.2; the current release checked on GitHub is
0.12.6. Compatibility is a target until the implementation is tested.

Provide lazy.nvim and `vim.pack` installation examples with the first usable
release. Respect LazyVim keymaps and global statusline settings. Document conflicts
with other zen or zoom plugins. Include help tags, Lua type annotations,
`:checkhealth zenon`, a minimal reproduction configuration, formatting checks,
and versioned releases with a short changelog.

Use event-driven, coalesced layout updates with recursion guards. Headless CI
should exercise the supported Neovim release range. Real terminal tests should
cover focus and navigation; headless checks alone cannot establish tmux behavior.

## Acceptance scenarios

| Scenario | Expected result |
| --- | --- |
| Enable and disable in one split | Width fits the bounds; cursor, view, options, and buffer contents survive. |
| Enter another split or lose editor focus | Zen remains enabled; the focused window remains usable. |
| Enable one buffer with two splits open | Other buffers keep their settings and zenon does not resize their splits. |
| Show one enabled buffer in two windows | Each view fits its host and preserves independent cursor and scroll state. |
| Change the buffer in a zen host | Apply the agreed buffer lifecycle rule and restore outgoing window options. |
| Open, resize, focus, and close nvim-tree | Zen stays enabled and fits the remaining space without stealing focus. |
| Resize below minimum, then enlarge | Fit available space; restore the preferred width when space returns. |
| Open a picker, completion menu, or LSP float | Tool remains usable and zen survives. |
| Close a host, wipe a buffer, or exit | Clean up owned resources without losing unsaved user text. |
| Invalid command arguments or a failing hook | Clear error; no partial layout or leaked global options. |
| Repeated setup or multiple zen buffers | No duplicate handlers and no premature restoration. |
| User changes an option while zen is active | Disabling zen preserves that later user choice. |

## License options

zenon will use original code. The reference plugin's Apache 2.0 license does
not require zenon to adopt Apache 2.0 simply for using similar editor options
or behavior. Keep its source outside the published tree and implement from the
requirements rather than translating or adapting that source.

| License | When it fits |
| --- | --- |
| MIT | A reasonable simple choice for this original implementation. Permissive, with a short notice requirement. |
| Apache 2.0 | Permissive, with an explicit contributor patent grant. Choose it if that protection matters. |
| GPL 3.0 | Consider if distributed derivatives should stay under the same license with corresponding source available. |

Apache and MIT allow proprietary derivatives; open source does not itself mean
that downstream changes must be published. GPL obligations generally attach to
conveying covered software, rather than private modifications.

Sources: [MIT text](https://opensource.org/license/mit),
[Apache licensing FAQ](https://www.apache.org/foundation/license-faq.html), and
[GPL 3.0 terms](https://choosealicense.com/licenses/gpl-3.0/).

The project license is still a decision for the owner. A public release must
include the selected license. Any separately approved third-party material
introduced later still needs its applicable terms and notices.

## Decisions before implementation

1. Confirm whether enabled state follows the buffer or the split.
2. Confirm centering within the host split and the percentage width basis.
3. Choose default minimum and maximum widths.
4. Choose the default editing profile and any visual-line navigation mapping.
5. Choose the project license and when to make the repository public.

Then build the layout prototype against the acceptance scenarios before settling
the rendering design and implementing the public interface.
