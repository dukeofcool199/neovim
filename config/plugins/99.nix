# 99 -- selection rewrite and project search driven by a CLI agent. Both its
# contexts are ordinary registry roles (`edit`, `search` in config/ai/registry.nix),
# so :AiModel, :AiPick, :AiStatus and a project's .nvim.lua reach them the same
# way they reach every other role.
{pkgs, ...}: let
  plugin-99 = pkgs.vimUtils.buildVimPlugin {
    name = "99";
    src = pkgs.fetchFromGitHub {
      owner = "whiteboardguy";
      repo = "99";
      rev = "9e39fb8f2370b2f4939ec4de9756b5dc656b84cf";
      sha256 = "sha256-UcEHjs9XCsoicSKanMqPRcFRI2xPaoAML+lWGK1D67o=";
    };
    patches = [
    ];
    doCheck = false;
  };
in {
  extraPlugins = [plugin-99];

  extraPackages = [pkgs.opencode];

  extraConfigLua = ''
    local _99 = require("99")
    local cwd = vim.uv.cwd()
    local basename = vim.fs.basename(cwd)

    -- A seed only: every op resolves its role again through ninetynine_run,
    -- so this is what 99 holds before the first keypress.
    _99.setup({
      logger = {
        level = _99.DEBUG,
        path = "/tmp/" .. basename .. ".99.debug",
        print_on_error = true,
      },
      tmp_dir = "./tmp",
      completion = {
        source = "native",
        -- Directories of <skill>/SKILL.md files.
        -- The 99-skills patch auto-includes these in every prompt context.
        custom_rules = {
          -- Global skills available in every project.
          vim.fn.expand("~/.claude/skills"),
          vim.fn.expand("~/.pi/agent/skills"),
          vim.fn.expand("~/.config/99/skills"),
          -- Project-specific skills resolved relative to cwd.
          ".claude/skills",
          ".pi/skills",
          ".pi/agent/skills",
          ".99/skills",
          "skills",
        },
      },
      -- Automatically inject all custom_rules skills into each prompt.
      auto_add_skills = true,
      md_files = {
        "AGENT.md",
      },
    })
  '';

  keymaps = [
    {
      mode = "v";
      key = "<leader>9v";
      action.__raw = ''
        function()
          _G.ninetynine_run("edit", "visual")
        end
      '';
      options = {
        desc = "99: visual replacement (edit role)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9s";
      action.__raw = ''
        function()
          _G.ninetynine_run("search", "search")
        end
      '';
      options = {
        desc = "99: search (search role)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9x";
      action.__raw = ''
        function()
          require("99").stop_all_requests()
        end
      '';
      options = {
        desc = "99: stop all requests";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9o";
      action.__raw = ''
        function()
          require("99").open()
        end
      '';
      options = {
        desc = "99: open last interaction";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9l";
      action.__raw = ''
        function()
          require("99").view_logs()
        end
      '';
      options = {
        desc = "99: view logs";
        silent = true;
        noremap = true;
      };
    }
  ];
}
