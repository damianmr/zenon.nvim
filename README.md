# zenon

A planned Neovim plugin for writing with a centered text area, adjustable width,
and zen mode that stays active while moving between splits and tmux panes.

The core will use Lua hooks for environment-specific behavior. The goal is to
keep other splits and tools such as nvim-tree usable while writing.

zenon will use an original implementation based on its requirements.
[zen-mode.nvim](https://github.com/folke/zen-mode.nvim) is a reference for editor
settings and behavior only.

This repository is at the design stage. It does not contain an installable
plugin yet.

- [Original requirements](FEATURES.md)
- [Design review and proposed behavior](DESIGN.md)
- [Contributor and agent instructions](AGENTS.md)

The intended installation targets are LazyVim through lazy.nvim and Neovim's
native packages, including `vim.pack` in Neovim 0.12.

## License decision

The project license has not been selected. MIT is a reasonable simple choice
for the planned original implementation; Apache 2.0 adds an explicit patent
grant. The [design review](DESIGN.md#license-options) compares these with GPL 3.0.
An open-source release needs a license and a public repository.
