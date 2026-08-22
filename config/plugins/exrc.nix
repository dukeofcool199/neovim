{...}: {
  # Enable Neovim's built-in project-local configuration (editor-native exrc).
  # Neovim searches the current working directory for, in order:
  #   - .nvim.lua   (recommended; full Lua, sandboxed until trusted)
  #   - .nvimrc     (vimscript, restricted when 'secure' is set)
  #   - .exrc       (vimscript, restricted when 'secure' is set)
  # On first encounter Neovim prompts to trust .nvim.lua files before running
  # them. Use :trust to manage trusted files.
  opts.exrc = true;
}
