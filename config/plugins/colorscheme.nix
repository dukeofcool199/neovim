{...}: {
  colorscheme = "gruvbox";

  colorschemes = {
    tokyonight = {
      enable = true;
    };

    gruvbox = {
      enable = true;
    };

    monokai-pro = {
      enable = true;
    };
  };
  extraConfigLua = ''
    -- in case i want colorschemes to be reactive
    function colorReactor(evt,pat,color)
        vim.api.nvim_create_autocmd(evt, {
        pattern = pat,
        callback = function()
          vim.cmd.colorscheme(color)
        end
      })
      end
  '';
}
