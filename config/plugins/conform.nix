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
        javascript = ["prettier"];
        javascriptreact = ["prettier"];
        typescript = ["prettier"];
        typescriptreact = ["prettier"];

        nix = ["alejandra"];
        lua = ["stylua"];

        c = ["clang-format"];
        cpp = ["clang-format"];
      };
    };
  };

  extraPackages = with pkgs; [
    nodejs
    alejandra
    stylua
    clang-tools
  ];
}
