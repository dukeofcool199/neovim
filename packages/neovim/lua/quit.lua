local which_key = require("which-key")

which_key.register({
	q = {
		Q = { "<cmd>q!<cr>", "Force Quit" },
		a = { "<cmd>qa!<cr>", "Force Quit All" }
		w = { "<cmd>wa<cr> <cmd>q!<cr>", "Save and Quit" },
		q = { "<cmd>q<cr>", "Close buffer" },
	}
}, { mode = "n", prefix = "<leader>", silent = true })
