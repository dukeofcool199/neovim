{pkgs, ...}: let
  notes = "~/notes";
in {
  plugins.orgmode = {
    enable = true;
    settings = {
      org_agenda_files = "${notes}/**/*";
      org_default_notes_file = "${notes}/refile.org";
      org_hide_leading_stars = true;
      org_hide_emphasis_markers = true;
      org_capture_templates.j = {
        description = "Journal";
        template = "* %<%H:%M> %?";
        target = "${notes}/journal.org";
        datetree = true;
      };
    };
  };

  # ~/notes is its own git repo; without this, entering a note would move the global cwd of
  # every project tab there. The notes tab gets a tab-local cwd instead. Both entries are
  # needed: project-nvim anchors each glob and checks file paths as well as directories.
  plugins.project-nvim.settings.exclude_dirs = [notes "${notes}/*"];

  keymaps = [
    {
      mode = "n";
      key = "<leader>oh";
      action.__raw = ''
        function()
          -- Found by tab variable, not cwd: project-nvim moves the global cwd on BufEnter.
          for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            if vim.t[tab].notes then
              vim.api.nvim_set_current_tabpage(tab)
              return
            end
          end
          local dir = vim.fn.expand("${notes}")
          vim.cmd.tabnew(dir .. "/index.org")
          vim.cmd.tcd(dir)
          vim.t.notes = true
        end
      '';
      options.desc = "Notes tab";
    }
    {
      mode = "n";
      key = "<leader>of";
      action.__raw = ''
        function()
          require("telescope.builtin").find_files({ cwd = vim.fn.expand("${notes}"), prompt_title = "Notes" })
        end
      '';
      options.desc = "Find a note";
    }
    {
      mode = "n";
      key = "<leader>og";
      action.__raw = ''
        function()
          require("telescope.builtin").live_grep({ cwd = vim.fn.expand("${notes}"), prompt_title = "Search notes" })
        end
      '';
      options.desc = "Search notes";
    }
  ];

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
