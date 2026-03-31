# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nixvim-based Neovim configuration. All configuration is written in Nix (`.nix` files), not Lua/VimScript directly. The Nix build system evaluates and templates Lua code at build time.

## Build & Test

```bash
# Build the Neovim package (produces ./result symlink)
nix build

# Run the built Neovim
./result/bin/nvim

# Check flake validity
nix flake check

# Print the generated init.lua
./result/bin/nixvim-print-init
```

There is no test suite or linter — validation is done by building (`nix build`) and running the result.

## Version Control

This repo uses **Jujutsu (jj)** as primary VCS (colocated with git). Always prefer `jj` commands over `git`. After making changes, run `jj git export` to sync to the git backend.

## Architecture

**Entry point:** `flake.nix` — Nix flake that builds Neovim via `nixvim.makeNixvimWithModule`, importing `./config`.

**Config module structure** (`config/`):
- `default.nix` — Root module: imports, extraPackages, colorscheme
- `options.nix` — Editor options (indentation, display, etc.)
- `keymaps.nix` — Global keybindings
- `lsp/default.nix` — LSP server configurations (25+ servers)
- `plugins/default.nix` — Imports all plugin modules
- `plugins/<name>.nix` — One file per plugin/feature

**Key pattern:** Plugins use `extraConfigLua` strings for complex Lua setup. Some plugins (scripture, jj) embed runtime Lua modules via `package.preload` and bake data into the build at Nix evaluation time.

**Custom plugins** are built inline using `pkgs.vimUtils.buildVimPlugin` with `fetchFromGitHub` (see `extra-plugins.nix`, `jj.nix`).

**Formatting** is handled by conform-nvim: `alejandra` for Nix, `stylua` for Lua, `standardjs` for JS/TS.

## Adding a New Plugin

1. Create `config/plugins/<name>.nix` following the Nixvim module pattern
2. Add the import to `config/plugins/default.nix`
3. Run `nix build` to verify
