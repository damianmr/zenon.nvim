# Working on zenon

zenon centers text for writing in Neovim. The repository is
`damianmr/zenon.nvim`; the Lua module and plugin name are `zenon`.

## Project context

- Read `README.md` for supported behavior and `DESIGN.md` for the layout and
  cleanup design. Keep the README and help file consistent with the code.
- Run `make test` for isolated headless tests and `make check` with StyLua 2.6.0.
- `ideas/zen-mode.nvim/` is an ignored, optional reference, not a dependency or
  submodule. The reviewed revision is
  `8564ce6d29ec7554eb9df578efa882d33b3c23a7` from
  `https://github.com/folke/zen-mode.nvim`.

## Behavior

- Write original code from the user's requirements. Use zen-mode only to review
  behavior and option choices. Do not copy, translate, or adapt its code.
- Keep the core independent of tmux, terminals, GUIs, and other plugins. Put
  optional adapters in `lua/zenon/integrations/`, use public plugin APIs, and
  do not load external plugins. Keep Lua hooks for custom behavior.
- Preserve the margin contract: `filetype=zenon-margin`, `w:zenon_padding`,
  `is_margin()`, and integration context metadata. Document contract changes in
  the help file. Test adapter cleanup, state restoration, and availability.
- Keep other splits, sidebars, and floating tools usable. Focus changes must not
  disable zenon. Enabled state belongs to the buffer.
- Support percentage width with an optional maximum and a minimum in screen
  columns. Use the host split, including margins. Define edge cases before coding.
- Preserve buffer contents, undo history, cursor, and view. Use the narrowest
  option scope. Restore owned state on disable, buffer replacement, window close,
  and failed initialization. Keep later user changes.
- Support Neovim 0.12+, lazy.nvim and LazyVim, and native packages with `vim.pack`.
- `:Zenon` enables or resizes; it never toggles off. `:Zenoff` disables. Neovim
  user commands must start with a capital letter.
- Keep writing mappings local to enabled buffers. Preserve existing buffer
  mappings and remove only mappings zenon still owns.

## Code and tests

- Use Lua, public Neovim APIs, and the standard `lua/`, `plugin/`, and `doc/`
  layout. Add runtime dependencies only for a concrete need.
- Keep the code small. Share repeated behavior through simple helpers. Add a
  layer only when it removes real duplication. Keep configuration, width
  calculation, rendering, and cleanup separate.
- Repeated setup must not add duplicate commands or autocommands. Clean up
  resources after errors. Validate input before changing state and report errors
  clearly.
- Schedule one update for related layout events. Avoid polling, expensive cursor
  handlers, and recursive resize loops.
- Test width bounds, buffer and window lifecycles, navigation, restoration, and
  sidebars. Wait for an expected result instead of sleeping for a fixed time.
  Restore test fixtures even after failures. Prefer public behavior over private
  implementation tables. Use a real terminal for focus and navigation checks.
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

The owner chose MIT; see `LICENSE`. Keep the implementation original and reference
checkouts out of the published tree. Preserve required notices for any separately
approved third-party code.

## Communication and GitHub

Use clear, simple English with correct grammar, as a fluent non-native speaker
would write it. Avoid flowery language, idioms, slang, and formal wording.

`GH_TOKEN` is available for GitHub CLI operations. Never print or commit it.
The user permits GitHub actions, including destructive actions. Stay within the
task, use existing history, and verify the remote before pushing. Do not
force-push for routine synchronization.
