local which_key = require("which-key")

which_key.register({
	g = {
		g = { "<cmd>e#<cr>", "Previous Buffer" },
	},
	t = {
		e = { "<cmd>tabedit ", "New Tab" },
		l = {
			"<cmd>tabnext<cr>",
			"Next Tab" },
		h = { "<cmd>tabprevious<cr>",
			"Previous Tab" }
	}
}, { mode = "n", prefix = "<leader>", silent = true })
