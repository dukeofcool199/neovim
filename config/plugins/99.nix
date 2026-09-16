# 99 -- selection rewrite and project search driven by a CLI agent. Both its
# contexts are ordinary registry roles (`edit`, `search` in config/ai/registry.nix),
# so :AiModel, :AiPick, :AiStatus and a project's .nvim.lua reach them the same
# way they reach every other role.
{pkgs, ...}: let
  registry = import ../ai/registry.nix;
  editRole = registry.roles.edit;
  editProvider = registry.agents.${editRole.backend}.provider;

  plugin-99 = pkgs.vimUtils.buildVimPlugin {
    name = "99";
    src = pkgs.fetchFromGitHub {
      owner = "dukeofcool199";
      repo = "99";
      rev = "c17422457027c913c76c75a921fca1e623d2678e";
      sha256 = "0jnbjgcvw72z0xjqngkc941wva9rv7ybqaldxlpp541mdy46jaca";
    };
    patches = [
      ./patches/99-opencode-fix.patch
      ./patches/99-skills.patch
      ./patches/99-claude-permissions.patch
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
      provider = _99.Providers.${editProvider},
      model = "${editRole.model}",
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

    -- Run a 99 op under its role's agent and model. Both are snapshotted
    -- synchronously into the request at creation, so this is race-free with
    -- the async prompt that follows.
    _G.ninetynine_run = function(role, fn)
      local r = require("ai").role(role)
      if not r then
        return vim.notify("99: no '" .. role .. "' role", vim.log.levels.WARN)
      end
      local provider = r.provider and _99.Providers[r.provider]
      if not provider then
        return vim.notify(
          ("99: %s is on '%s', which is not a CLI agent 99 can drive"):format(role, tostring(r.backend)),
          vim.log.levels.WARN
        )
      end
      -- set_provider resets the model to that provider's own default, so the
      -- order here is forced.
      _99.set_provider(provider)
      _99.set_model(r.model)
      require("99")[fn]()
    end
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
    {
      mode = "n";
      key = "<leader>9m";
      action.__raw = ''
        function()
          require("ai").pick("edit")
        end
      '';
      options = {
        desc = "99: set edit agent and model";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9M";
      action.__raw = ''
        function()
          require("ai").pick("search")
        end
      '';
      options = {
        desc = "99: set search agent and model";
        silent = true;
        noremap = true;
      };
    }
  ];
}
