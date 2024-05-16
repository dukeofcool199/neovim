local which_key = require("which-key")

require('copilot').setup({
  panel = {
    enabled = false,
    auto_refresh = false,
    keymap = {
      jump_prev = "[[",
      jump_next = "]]",
      accept = "<CR>",
      refresh = "gr",
      open = "<M-CR>"
    },
    layout = {
      position = "right", -- | top | left | right
      ratio = 0.4
    },
  },
  suggestion = {
    enabled = true,
    auto_trigger = true,
    debounce = 75,
    keymap = {
      accept = "<C-A>",
      accept_word = false,
      accept_line = false,
      next = "<C-]>",
      prev = "<C-[>",
    },
  },
  filetypes = {
    yaml = false,
    markdown = false,
    help = false,
    gitcommit = false,
    gitrebase = false,
    hgcommit = false,
    svn = false,
    text = false,
    txt = false,
    cvs = false,
    ["."] = false,
  },
  copilot_node_command = 'node', -- Node.js version must be > 18.x
  server_opts_overrides = {},
})

which_key.register({
  p = {
    name = "Copilot",
    p = { "<cmd>:Copilot panel<CR>", "toggle copilot panel" },
    s = { "<cmd>:Copilot suggestion<CR>", "toggle copilot suggestsions" }
  }
}, { mode = "n", prefix = "<leader>", noremap = true, silent = true })
