local which_key = require("which-key")

which_key.register({
		q = { q = {"<cmd>q!<cr>", "Force Quit"}, w = {"<cmd>wa<cr> <cmd>q!<cr>", "Save and Quit"} }
}, { mode = "n", prefix = "<leader>", silent = true })
