{ pkgs, ... }:
{
  plugins.conform-nvim = {
    enable = true;

    settings = {
      formatters_by_ft = {
        javascript = [ "prettier" ];
        typescript = [ "prettier" ];
        javascriptreact = [ "prettier" ];
        typescriptreact = [ "prettier" ];
        vue = [ "prettier" ];
        html = [ "prettier" ];
        css = [ "prettier" ];
        json = [ "prettier" ];
        yaml = [ "prettier" ];
        markdown = [ "prettier" ];
      };

      format_on_save = {
        timeout_ms = 500;
        lsp_fallback = true;
      };

      notify_on_error = true;
    };
  };

  # Make prettier available in PATH
  extraPackages = with pkgs; [
    nodePackages.prettier
  ];
}
