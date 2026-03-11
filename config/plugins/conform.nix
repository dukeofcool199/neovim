{pkgs, ...}: {
  plugins.conform-nvim = {
    enable = true;

    settings = {
      notify_on_error = true;

      format_on_save = {
        timeout_ms = 4000;
        lsp_fallback = true;
      };

      formatters_by_ft = {
        javascript = ["standardjs"];
        javascriptreact = ["standardjs"];
        typescript = ["standardjs"];
        typescriptreact = ["standardjs"];

        nix = ["alejandra"];
        lua = ["stylua"];
      };
    };
  };

  extraPackages = with pkgs; [
    nodejs
    alejandra
    stylua
  ];
}
