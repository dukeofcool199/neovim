local which_key = require("which-key")


which_key.register({
  z = {
    name = "Zen mode",
    z = { "<cmd>:ZenMode<cr>", "toggle zen mode" },
  },
}, { mode = "n", prefix = "<leader>" })
