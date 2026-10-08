{pkgs, ...}: {
  plugins.orgmode = {
    enable = true;
    settings = {
      org_agenda_files = "~/notes/**/*";
      org_default_notes_file = "~/notes/refile.org";
      org_hide_leading_stars = true;
      org_hide_emphasis_markers = true;
      org_capture_templates.j = {
        description = "Journal";
        template = "* %<%H:%M> %?";
        target = "~/notes/journal.org";
        datetree = true;
      };
    };
  };

  plugins.cmp.settings.sources = [{name = "orgmode";}];

  plugins.otter = {
    enable = true;
    # Its LspAttach hook would activate otter in every LSP buffer, not just org.
    autoActivate = false;
    settings.handle_leading_whitespace = true;
  };

  # image.nvim has no org integration; orgmode ships queries/org/images.scm for snacks.
  # snacks would otherwise attach to every language with an images.scm and hijack image
  # files, both of which image.nvim already owns.
  plugins.snacks = {
    enable = true;
    settings.image = {
      enabled = true;
      formats.__empty = null;
      doc.enabled = false;
    };
  };
  extraPackages = [pkgs.imagemagick];

  extraConfigLua = ''
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "org",
      callback = function(ev)
        require("otter").activate()
        Snacks.image.doc.attach(ev.buf)
      end,
    })
  '';
}
