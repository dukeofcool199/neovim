local which_key = require("which-key")


which_key.register({
	t = {
		name = "Toggle",
		z = { "<cmd>:ZenMode<cr>", "toggle zen mode" },
	},
}, { mode = "n", prefix = "<leader>" })
