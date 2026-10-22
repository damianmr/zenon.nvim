# Working on zenon

zenon is a Neovim plugin for writing with a centered text area. The GitHub
repository is `damianmr/zenon`; the Lua module and user-facing name are `zenon`.

## Project context

- Read `FEATURES.md` for the original requirements and `DESIGN.md` for the
  analysis, proposed behavior, unresolved choices, and acceptance scenarios.
- Keep original requirements separate from proposals. Do not treat unanswered
  questions in `DESIGN.md` as approved decisions.
- This repository starts with planning documents. There is no plugin
  implementation or project test command yet.
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
  `vim.pack` on Neovim 0.12. Choose and document the minimum Neovim version
  before implementation.
- Use the command name `:Zenon`; Neovim user commands start with a capital
  letter. Do not install lowercase command abbreviations or keymaps by default.

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

The project license is pending. The implementation must be original, so the
reference plugin's license does not determine zenon's license. `DESIGN.md`
compares MIT, Apache 2.0, and GPL 3.0. Keep the reference checkout outside the
published tree. Preserve applicable notices for any separately approved
third-party material introduced later.

## Communication and GitHub

Use clear, natural English with simple words and correct grammar. Avoid
flowery language, idioms, slang, and overly formal wording.

`GH_TOKEN` is available for authenticated GitHub CLI operations. Never print or
commit it. The user permits GitHub actions, including destructive actions;
still keep changes within the requested task. Use the repository's existing
history and verify the remote before pushing. Do not force-push for routine
synchronization.
