# 99 -- selection rewrite and project search, driven by the claude CLI.
{pkgs, ...}: let
  plugin-99 = pkgs.vimUtils.buildVimPlugin {
    name = "99";
    src = pkgs.fetchFromGitHub {
      owner = "whiteboardguy";
      repo = "99";
      rev = "9e39fb8f2370b2f4939ec4de9756b5dc656b84cf";
      sha256 = "sha256-UcEHjs9XCsoicSKanMqPRcFRI2xPaoAML+lWGK1D67o=";
    };
    doCheck = false;
  };
in {
  extraPlugins = [plugin-99];

  extraConfigLua = ''
    local _99 = require("99")
    _99.setup({
      provider = _99.Providers.ClaudeCodeProvider,
      model = "sonnet",
      logger = {
        level = _99.DEBUG,
        path = "/tmp/" .. vim.fs.basename(vim.uv.cwd()) .. ".99.debug",
        print_on_error = true,
      },
      -- Outside cwd, claude's permission checks reject the temp files.
      tmp_dir = "./tmp",
      completion = {
        custom_rules = {
          vim.fn.expand("~/.claude/skills"),
          ".claude/skills",
        },
      },
      md_files = {
        "AGENT.md",
        "CLAUDE.md",
      },
    })
  '';

  keymaps = [
    {
      mode = "v";
      key = "<leader>9v";
      action.__raw = ''function() require("99").visual() end'';
      options = {
        desc = "99: rewrite selection";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9s";
      action.__raw = ''function() require("99").search() end'';
      options = {
        desc = "99: search project";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9x";
      action.__raw = ''function() require("99").stop_all_requests() end'';
      options = {
        desc = "99: stop all requests";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9o";
      action.__raw = ''function() require("99").open() end'';
      options = {
        desc = "99: open last interaction";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9l";
      action.__raw = ''function() require("99").view_logs() end'';
      options = {
        desc = "99: view logs";
        silent = true;
        noremap = true;
      };
    }
  ];
}
