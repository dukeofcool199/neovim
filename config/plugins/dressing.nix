{pkgs, ...}: {
  extraPlugins = [pkgs.vimPlugins.dressing-nvim];

  extraConfigLua = ''
    local dressing_ok, dressing = pcall(require, "dressing")
    if dressing_ok then
      dressing.setup({
        input = {
          enabled = true,
          default_prompt = "Input:",
          start_in_insert = true,
          border = "rounded",
          relative = "cursor",
          prefer_width = 40,
          win_options = {
            winblend = 0,
          },
        },
        select = {
          enabled = true,
          backend = { "telescope", "builtin" },
        },
      })
    end
  '';
}
