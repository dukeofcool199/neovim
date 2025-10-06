# CRUSH.md

## Build & Install
- **Try Without Installing:**
  - `nix run github:dukeofcool199/neovim`
- **Imperative Install:**
  - `nix profile install github:dukeofcool199/neovim`
- **Add to flake:**
  - Add as an input, see the README.md for full snippet

## Testing & Linting
- **Tests:** No explicit tests found in this repository.
- **Linting:** No linting configuration/tools found (e.g., no luacheck, stylua, etc).
- **Format:** No formatting tools/scripts detected.
- **Run Single Test:** Not applicable.

## Code Style Guidelines (Lua)
- **Indentation:** 2 spaces, no tabs
- **Imports:**
  - Use `local x = require("x")` and group at the file top
- **Naming:**
  - snake_case for variables/functions
  - camelCase for plugin/method names if following plugin conventions
- **Functions:** Prefer local, keep them short/single-purpose
- **Error handling:** Fail early, check return values when APIs provide errors, lean on Neovim/Lua error output
- **Formatting:** No trailing whitespace; arguments/fields aligned, one property per line in tables
- **Comments:** Only as needed for complex logic
- **Mapping conventions:** Use descriptive key names in keymaps, follow nvim plugin conventions

## Project Structure
- All configuration is under `packages/neovim/`, especially:
  - `lua/` for major plugin and editor configuration
  - `vim/` for vimscript if needed (minimal)

## Editor/Formatting rules
- No `.editorconfig`, Prettier config, or other enforcement—default to Lua community norms

## Cursor & Copilot rules
- No rules detected (.cursor/rules/, .cursorrules, or .github/copilot-instructions.md)

---
This file guides coding agents on best practices and build commands in this repo. Update if adding any CI, lint, or test infra.
