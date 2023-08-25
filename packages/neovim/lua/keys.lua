local function map(mode, lhs, rhs, opts)
	local options = { noremap = true }

	if opts then
		options = vim.tbl_extend("force", options, opts)
	end

	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- Exit terminal mode.
map("t", "<C-o>", "<C-\\><C-n>", { silent = true })
map("n", "<C-k>", ":wincmd k<cr>", { silent = true })
map("n", "<C-j>", ":wincmd j<cr>", { silent = true })
map("n", "<C-h>", ":wincmd h<cr>", { silent = true })
map("n", "<C-l>", ":wincmd l<cr>", { silent = true })
