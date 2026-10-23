# Working on zenon.nvim

`zenon.nvim` centers text for writing in Neovim. The repository is
`damianmr/zenon.nvim`. Use `zenon.nvim` in prose. Keep the Lua module `zenon`,
the commands, and the margin identifiers unchanged.

## Project context

- Read `README.md` for user behavior and `doc/zenon.txt` for all options, width
  rules, and the integration API. Keep both in sync with the code.
- Run `make test` for isolated headless tests and `make check` with StyLua 2.6.0.
- `ideas/zen-mode.nvim/` is an ignored, optional reference, not a dependency or
  submodule. The reviewed revision is
  `8564ce6d29ec7554eb9df578efa882d33b3c23a7` from
  `https://github.com/folke/zen-mode.nvim`.
- `ideas/zen.nvim/` is another ignored reference. The reviewed revision is
  `e1f0b3be2d78ec9d4386aefc86f03f17c4c41b29` from
  `https://github.com/sand4rt/zen.nvim`.

## Behavior

- Write original code from the user's requirements. Use reference plugins only
  to review behavior and options. Do not copy, translate, or adapt their code.
- Keep the core independent of tmux, terminals, GUIs, and other plugins. Put
  optional adapters in `lua/zenon/integrations/`, use public plugin APIs, and
  do not load external plugins. Keep Lua hooks for custom behavior.
- Preserve the margin contract: `filetype=zenon-margin`, `w:zenon_padding`,
  `is_margin()`, and integration context metadata. Document contract changes in
  the help file. Test adapter cleanup, state restoration, and availability.
- Keep other splits, sidebars, and floating tools usable. Focus changes must not
  disable zenon.nvim. Enabled state belongs to the buffer.
- Support percentage width with an optional maximum and a minimum in screen
  columns. Use the host split, including margins. Define edge cases before coding.
- Preserve buffer contents, undo history, cursor, and view. Use the narrowest
  option scope. Restore state owned by zenon.nvim on disable, buffer replacement,
  window close, and failed initialization. Keep later user changes.
- Support Neovim 0.12+, lazy.nvim and LazyVim, and native packages with `vim.pack`.
- `:Zenon` enables or resizes; it never toggles off. `:Zenoff` disables. Neovim
  user commands must start with a capital letter.
- Keep writing mappings local to enabled buffers. Preserve existing buffer
  mappings and remove only mappings zenon.nvim still owns.

## Layout and cleanup

- Keep one session per enabled buffer and one view per editing window. A hidden
  enabled buffer keeps its session. Returning to it creates a new view.
- The host width includes the text window, margins, and separators. Subtract
  gutters such as line numbers before applying the percentage. Minimum and
  maximum widths count text columns. Use the available width if it is too small
  for the minimum.
- `WinNewPre` may read the source window but must not change its layout. During
  `WinNew`, a new window may still show the source buffer. Update the layout
  after Neovim assigns the new buffer. Share old margin space between new
  splits. Keep sizes set later by the user or a sidebar.
- Preserve `equalalways`, `winfixwidth`, and `winfixheight` during layout changes.
  Avoid a resize when margins already have the requested width.
- Save raw local option values, including inherited values. Restore options and
  mappings only while they still match what zenon.nvim set. If `:close` leaves only
  margins, reuse one to keep the file visible.
- Keep one attachment per adapter while an enabled buffer requests it. Give
  each callback a separate context snapshot. If an adapter fails, finish cleanup
  and let other adapters work. Retry it after disable and enable.

## Code and tests

- Use Lua, public Neovim APIs, and the standard `lua/`, `plugin/`, and `doc/`
  layout. Add runtime dependencies only for a concrete need.
- Keep the code small. Use simple helpers for repeated behavior. Add a layer
  only when it removes real duplication. Keep configuration, width calculation,
  rendering, and cleanup separate.
- Repeated setup must not add duplicate commands or autocommands. Clean up
  resources after errors. Validate input before changing state and report errors
  clearly.
- Schedule one update for related layout events. Avoid polling, expensive cursor
  handlers, and recursive resize loops.
- Test width bounds, buffer and window lifecycles, navigation, restoration, and
  sidebars. Wait for expected results instead of sleeping for a fixed time.
  Restore test fixtures even after failures. Prefer public behavior over private
  implementation tables. Use a real terminal for focus and navigation checks.
- Compare split widths with native Neovim. Test several splits before a scheduled
  update and buffer assignment after `WinNew`. Fail on unexpected plugin warnings.
- Document working behavior and provide valid installation examples. Do not
  describe planned features as available.
- Do not commit local references, personal configuration, logs, credentials,
  generated help tags, or build output.
- Use official GitHub actions directly. Fork other actions into `damianmr`.
  Pin every action to a full commit SHA and comment its upstream name and version.

## Releases

- Use the manual `Release` workflow on `main`. Routine commits need no release.
- Use `vMAJOR.MINOR.PATCH`. Bump patch for fixes, minor for features, and major
  for breaking changes. Before 1.0, bump minor for breaking changes.
- Require CI to pass and tag the exact tested commit. Use the workflow's dry run
  to check the process without publishing.
- Never change a published tag or replace release assets. Keep GitHub release
  immutability enabled. Publish a new version for fixes.
- Describe changes users will notice and list upgrade steps in release notes,
  especially for options, commands, defaults, or the minimum Neovim version.
- Once a release exists, pin installation examples to a published tag and keep
  them current. Never use a tag that does not exist.

## License

The license is MIT; see `LICENSE`. Keep the code original and reference checkouts
out of the published tree. Keep required notices for any separately approved
third-party code.

## Communication and GitHub

Use clear, simple English with correct grammar, as a fluent non-native speaker
would write it. Avoid flowery language, idioms, slang, and formal wording.

`GH_TOKEN` is available for GitHub CLI operations. Never print or commit it.
The user permits GitHub actions, including destructive actions. Stay within the
task, use existing history, and verify the remote before pushing. Do not
force-push for routine synchronization.
