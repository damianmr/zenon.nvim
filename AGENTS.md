# Working on zenon

zenon is a Neovim plugin for writing with a centered text area. The GitHub
repository is `damianmr/zenon`; the Lua module and user-facing name are `zenon`.

## Project context

- Read `README.md` for supported behavior and configuration, and `DESIGN.md`
  for the implemented architecture and verification approach.
- Run `make test` for isolated headless Neovim integration tests. Run
  `make check` with StyLua 2.6.0 for formatting.
- Keep the README and help file aligned with working behavior.
- `ideas/zen-mode.nvim/` is an optional, ignored reference checkout. It is not a
  dependency or a submodule. The reviewed revision is
  `8564ce6d29ec7554eb9df578efa882d33b3c23a7` from
  `https://github.com/folke/zen-mode.nvim`.

## Product constraints

- Implement zenon from the user's requirements with original code. Use
  zen-mode only as a reference for behavior and editor option choices. Do not
  copy, translate, or mechanically adapt its implementation.
- Keep the core independent of tmux, terminal emulators, GUIs, and other plugins.
  Expose Lua lifecycle hooks for user-defined integrations.
- Preserve normal use of other splits, sidebars, and floating tools.
- Leaving a window or losing application focus must not disable zen mode.
- Support configuration and runtime width changes with a percentage, maximum,
  and minimum, measured in screen columns. Specify edge cases before coding.
- Preserve the user's buffer contents, undo history, cursor, and view.
- Apply options with the narrowest appropriate scope. Restore changed state
  on disable, buffer replacement, window close, and failed initialization.
- Support LazyVim through lazy.nvim and native Neovim packages, including
  `vim.pack` on Neovim 0.12. The minimum Neovim version is 0.12.
- Use the command name `:Zenon`; Neovim user commands start with a capital
  letter. `:Zenon` enables or resizes; `:Zenoff` disables. Do not turn
  `:Zenon` into a toggle. Width percentages use the host split.
- Writing mappings belong to enabled buffers. Preserve existing buffer-local
  mappings and restore only mappings and options still owned by zenon.

## Implementation and review

- Use Lua, the standard `lua/`, `plugin/`, and `doc/` layout, public Neovim APIs,
  and no required runtime dependencies unless there is a concrete need.
- Keep configuration, width calculation, rendering, and state cleanup separate.
- Keep setup repeatable. Register namespaced autocommands and commands without
  accumulating duplicate handlers. Clean up resources after errors.
- Avoid polling and expensive cursor-event work. Coalesce layout updates and
  prevent recursive resize handlers.
- Validate input before changing editor state. Report invalid values clearly.
- Test meaningful behavior: width boundaries, buffer and window lifecycle,
  normal split navigation, restoration, and sidebar interactions. Use isolated
  headless Neovim for automated checks and a real terminal for focus behavior.
- Add help documentation and accurate installation examples with the first
  usable implementation. Do not describe planned features as working features.
- Do not commit local reference repositories, personal configuration, logs,
  credentials, generated help tags, or build output.

## Licensing

The owner selected MIT; see `LICENSE`. The implementation must remain original.
Keep the reference checkout outside the published tree. Preserve applicable
notices for any separately approved third-party material introduced later.

## Communication and GitHub

Use clear, natural English with simple words and correct grammar. Avoid
flowery language, idioms, slang, and overly formal wording.

`GH_TOKEN` is available for authenticated GitHub CLI operations. Never print or
commit it. The user permits GitHub actions, including destructive actions;
still keep changes within the requested task. Use the repository's existing
history and verify the remote before pushing. Do not force-push for routine
synchronization.
