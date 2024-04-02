local which_key = require("which-key")

vim.api.nvim_create_augroup("bufcheck", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = "bufcheck",
  pattern = { "gitcommit", "gitrebase" },
  command = "startinsert | 1",
})

which_key.register({
  g = {
    name = "Git",
    w = { "<cmd>:Gwrite<cr>", "Git write" },
    c = { "<cmd>:G commit<cr>", "Git commit" },
    p = { "<cmd>:Git push<cr>", "Git push" }
  }
}, { mode = "n", prefix = "<leader>" })
