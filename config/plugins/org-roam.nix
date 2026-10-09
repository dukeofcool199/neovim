# org-roam.nvim: ID-linked notes in ~/notes with backlinks and dailies, on <leader>n.
# Pinned past the nixpkgs rev for upstream #138: backlinks to filenames with spaces broke.
{pkgs, ...}: let
  org-roam-nvim = pkgs.vimPlugins.org-roam-nvim.overrideAttrs {
    src = pkgs.fetchFromGitHub {
      owner = "chipsenkbeil";
      repo = "org-roam.nvim";
      rev = "aa41b86138d337c485b6cdcffa4b45a61d23edf1";
      hash = "sha256-uqlc1on9MSZhmn099PDNfMy9O3KpRVZmxOHYPWhw/oQ=";
    };
  };
in {
  extraPlugins = [org-roam-nvim];

  extraConfigLua = ''
    require("org-roam").setup({
      directory = "~/notes",
      templates = {
        d = { description = "default", template = "%?", target = "%[slug].org" },
      },
      immediate = { target = "%[slug].org", template = "" },
      extensions = {
        dailies = {
          templates = {
            -- Dailies navigation only finds files named YYYY-MM-DD.org (upstream #90). Dailies
            -- fills %<...> from the chosen day's midnight, so the entry time comes from Lua.
            d = {
              description = "default",
              template = '* %(return os.date("%H:%M")) %?',
              target = "%<%Y-%m-%d>.org",
            },
          },
        },
      },
    })

    -- Store-link (<leader>ols) only gives headings an ID; files made outside roam need this.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "org",
      callback = function(ev)
        vim.api.nvim_buf_create_user_command(ev.buf, "OrgId", function()
          local files = require("orgmode").files
          local entry = files:get_closest_headline_or_nil() or files:get_current_file()
          vim.api.nvim_echo({ { "ID " .. entry:id_get_or_create() } }, false, {})
        end, { desc = "Give the heading at the cursor, or the file above its first heading, an ID" })
      end,
    })
  '';
}
