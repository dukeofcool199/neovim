{pkgs, ...}: {
  extraPlugins = [pkgs.vimPlugins.render-markdown-nvim];

  extraConfigLua = ''
    local render_markdown_ok, render_markdown = pcall(require, "render-markdown")
    if render_markdown_ok then
      render_markdown.setup({
        file_types = { "markdown", "Avante" },
      })
    end
  '';
}
