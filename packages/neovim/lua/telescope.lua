local which_key = require("which-key")
local telescope = require("telescope")
local api = require("telescope.builtin")


telescope.setup {
  defaults = {
    mappings = {
      i = {
        ["<C-h>"] = "which_key"
      },
    },
  },
}

which_key.register({
  f = {
    name = "File",
    e = { telescope.extensions.gitmoji.gitmoji, "Find Gitmojis" },
    f = { "<cmd>Telescope find_files<cr>", "Find File" },
    F = { function()
      api.find_files { hidden = true }
    end
    , "Find File (Hidden)" },
    r = { "<cmd>Telescope oldfiles<cr>", "Recent File" },
    g = { "<cmd>Telescope live_grep<cr>", "Grep" },
    G = { function()
      api.live_grep { hidden = true }
    end, "Grep (Hidden Files)" },
    b = { "<cmd>Telescope buffers<cr>", "Find Buffer" },
  },
  p = {
    p = { "<cmd>Telescope find_files<cr>", "Find File" }
  }
}, { mode = "n", prefix = "<leader>", silent = true })

which_key.register({
  ["<C-p>"] = { "<cmd>Telescope find_files<cr>", "Find File" },
  ["<C-c>"] = { "<cmd>Telescope commands<cr>", "Run Command" }
})
