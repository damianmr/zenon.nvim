- This plugin is called zenon, it's to enable zen mode during writing.

- Implement it from these requirements with original code. Use zen-mode only
  as inspiration for editor settings and behavior; do not copy its code.

- I don't want tmux integration or code that is intended to address a specific environment. If that's needed, the user must be able to set it up through an extension hook that our plugin executes.

- I'd like to use a ZenMode that uses 50% of the screen, within a certain minimum and maximum, it could be set during config but it should be possible to do so like :zenon 55, or zenon 55 600 or zenon 55 600 120 (:zenon <terminal_size percentage> <maximum> <minimum>)

- When I switch to a different pane within tmux zenmode loses zen mode. I don't know why that happens but i don't want it. I want to stay in zen mode, respecting the size contraints above. I lose the zen mode when I hit Ctrl+hjkl.

- the Zen mode in zenon applies to buffers... If I have more splits in my view then leave those as is.

- I like the initial config the plugin zenmode applies to the vim config in terms of editing (navigation across pure text). Can you tell me what is it doing exactly? We want to replicate those settings.

- I should be able to open nvim-tree without affecting the zen mode.

- The plugin must be compatible with lazyvim and the default package manager of nvim (v12).

- What good practices should we apply for this nvim plugin?
