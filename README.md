# zenon.nvim

A planned Neovim plugin for writing with a centered text area, adjustable width,
and zen mode that stays active while moving between splits and tmux panes.

The core will use Lua hooks for environment-specific behavior. The goal is to
keep other splits and tools such as nvim-tree usable while writing.

This repository is at the design stage. It does not contain an installable
plugin yet.

- [Original requirements](FEATURES.md)
- [Design review and proposed behavior](DESIGN.md)
- [Contributor and agent instructions](AGENTS.md)

The intended installation targets are LazyVim through lazy.nvim and Neovim's
native packages, including `vim.pack` in Neovim 0.12.

## License decision

The project license has not been selected. Apache 2.0 is the current
recommendation, especially if code is adapted from
[folke/zen-mode.nvim](https://github.com/folke/zen-mode.nvim).
The [design review](DESIGN.md#license-options) explains the choices and the
conditions for reusing upstream code. An open-source release needs a license
and a public repository.
