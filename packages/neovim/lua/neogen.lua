require('neogen').setup {}
local which_key = require("which-key")

which_key.register({
  n = {
    name = "New",
    c = { "<cmd>:Neogen<cr>", "doc comment" }
  }
}, { mode = "n", prefix = "<leader>" })
