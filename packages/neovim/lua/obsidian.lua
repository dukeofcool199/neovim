require("obsidian").setup({
  workspaces = {
    {
      name = "personal",
      path = "~/annex/nb",
    },

  }
  follow_url_func = function(url)
    vim.fn.jobstart({ "brave", url })
  end,

})
