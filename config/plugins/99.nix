{pkgs, ...}: let
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

    -- Two models are tracked independently at runtime, one per context:
    --   * edit   -> visual replacement. gpt-5.6-fast: low latency -> snappy
    --               edits / quick agent loops.
    --   * search -> project search. gpt-5.6-pro: strongest reasoning -> synthesis
    --               and multi-step analysis.
    -- Both resolve through opencode (ChatGPT Pro auth); no provider injection.
    -- Each is chosen live from `opencode models` via <leader>9m / <leader>9M and
    -- both are shown in the statusline. These are the startup defaults:
    _G.ninetynine_models = _G.ninetynine_models or {
      edit = "openai/gpt-5.5",
      search = "openai/gpt-5.5",
    }

    local function refresh_lualine()
      local ok, lualine = pcall(require, "lualine")
      if ok then
        lualine.refresh()
      end
    end

    _99.setup({
      provider = _99.Providers.OpenCodeProvider,
      model = _G.ninetynine_models.edit,
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

    -- List models opencode can reach (one `provider/model` id per line).
    local function opencode_models(cb)
      vim.system({ "opencode", "models" }, { text = true }, function(obj)
        vim.schedule(function()
          if obj.code ~= 0 then
            vim.notify("99: `opencode models` failed", vim.log.levels.ERROR)
            return
          end
          cb(vim.split(obj.stdout, "\n", { trimempty = true }))
        end)
      end)
    end

    -- Assign a freshly picked model id (full `provider/model`) to a context.
    local function set_context_model(ctx, id)
      _G.ninetynine_models[ctx] = id
      refresh_lualine()
      vim.notify("99: " .. ctx .. " model -> " .. id)
    end

    -- Picker (telescope if present, else vim.ui.select) to set a context model.
    -- ctx is "edit" or "search".
    _G.ninetynine_pick_model = function(ctx)
      opencode_models(function(models)
        if #models == 0 then
          vim.notify("99: no opencode models available", vim.log.levels.WARN)
          return
        end
        local title = "99: select " .. ctx .. " model"
        local ok, pickers = pcall(require, "telescope.pickers")
        if not ok then
          vim.ui.select(models, { prompt = title }, function(choice)
            if choice then
              set_context_model(ctx, choice)
            end
          end)
          return
        end
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")
        pickers
          .new({}, {
            prompt_title = title,
            finder = finders.new_table({ results = models }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(bufnr)
              actions.select_default:replace(function()
                actions.close(bufnr)
                local sel = action_state.get_selected_entry()
                if sel then
                  set_context_model(ctx, sel[1])
                end
              end)
              return true
            end,
          })
          :find()
      end)
    end

    -- Run a 99 op under its context's model. set_model snapshots synchronously
    -- into the request at creation, so this is race-free with the async prompt.
    _G.ninetynine_run = function(ctx, fn)
      _99.set_model(_G.ninetynine_models[ctx])
      require("99")[fn]()
    end

    -- Statusline helper: show both context models (short form, provider stripped)
    _G.ninetynine_lualine_model = function()
      local m = _G.ninetynine_models or {}
      local function short(x)
        return (x or "?"):gsub("^.-/", "")
      end
      return string.format("󰚩 e:%s  s:%s", short(m.edit), short(m.search))
    end

    local orig_set_model = _99.set_model
    _99.set_model = function(model)
      local res = orig_set_model(model)
      refresh_lualine()
      return res
    end

    local orig_set_provider = _99.set_provider
    _99.set_provider = function(provider)
      local res = orig_set_provider(provider)
      refresh_lualine()
      return res
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
        desc = "99: visual replacement (edit model)";
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
        desc = "99: search (search model)";
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
          _G.ninetynine_pick_model("edit")
        end
      '';
      options = {
        desc = "99: set edit model";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9M";
      action.__raw = ''
        function()
          _G.ninetynine_pick_model("search")
        end
      '';
      options = {
        desc = "99: set search model";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9p";
      action.__raw = ''
        function()
          require("99.extensions.telescope").select_provider()
        end
      '';
      options = {
        desc = "99: select provider (telescope)";
        silent = true;
        noremap = true;
      };
    }
  ];
}
