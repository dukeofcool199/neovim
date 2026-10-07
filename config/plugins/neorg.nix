{pkgs, ...}: {
  plugins.neorg = {
    enable = true;
    telescopeIntegration.enable = true;

    settings.load = {
      "core.defaults".__empty = null;
      "core.concealer".__empty = null;
      "core.dirman".config = {
        workspaces.notes = "~/notes";
        default_workspace = "notes";
      };
      "core.completion".config.engine = "nvim-cmp";
      "core.integrations.telescope".__empty = null;
      "core.integrations.otter".config.auto_start = false;
      "core.summary".__empty = null;
      "core.export".__empty = null;
      "core.export.markdown".__empty = null;
      "core.export.html".__empty = null;
      # The presenter refuses to load without a zen_mode. zen-mode.nvim isn't installed, and
      # neorg 9.6.4's hook requires "zen_mode" (a misspelling) anyway, so no zen runs.
      "core.presenter".config.zen_mode = "zen-mode";
      "core.latex.renderer".__empty = null;
    };
  };

  plugins.cmp.settings.sources = [{name = "neorg";}];

  # Not plugins.otter: its setup({}) would win over neorg's otter.setup, which enables
  # handle_leading_whitespace for code blocks indented under headings.
  extraPlugins = [pkgs.vimPlugins.otter-nvim];

  # neorg's otter auto_start fires on BufReadPost ahead of filetype detection, so otter
  # sees no filetype and refuses to activate.
  extraConfigLua = ''
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "norg",
      callback = function()
        require("neorg.core").modules.get_module("core.integrations.otter").activate()
      end,
    })
  '';
}
