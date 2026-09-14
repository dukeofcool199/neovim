# avante.nvim -- the agentic sidebar behind <leader>aa: chat with the code in
# view, tool calls, edits reviewed as diffs. Bound to the `agent` role in
# config/ai/registry.nix, and drawn in the same panel as sidekick.
#
# Nothing here chooses a backend. Avante is not set up at all until the role
# has one, which a project supplies in .nvim.lua:
#
#   require("ai").setup({agent = {backend = "claude-code", model = "claude-sonnet-5"}})
#
# or <leader>aA picks for the session. claude-code and opencode speak ACP and
# bring their own credentials; opencode-go is OpenCode Go's HTTP endpoint.
{
  config,
  lib,
  pkgs,
  ...
}: let
  registry = import ../ai/registry.nix;
  go = registry.endpoints.opencode-go;
in {
  extraPackages = [pkgs.claude-agent-acp pkgs.opencode];

  plugins.avante = {
    enable = true;
    # Inline edit replaces the selection with whatever the reply wraps in
    # <code>; upstream does that on every chunk, so a reply without one
    # (an agent's prose, a tool call) deletes the selection outright.
    package = pkgs.vimPlugins.avante-nvim.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./patches/avante-edit-keep-selection.patch];
    });
    # ai.avante calls setup once a backend is known.
    callSetup = false;

    settings = {
      mode = "agentic";

      behaviour = {
        # <leader>a belongs to config/ai/actions.nix.
        auto_set_keymaps = false;
        # Ghost text needs an HTTP provider on every keystroke; off until wanted.
        auto_suggestions = false;
        auto_apply_diff_after_generation = false;
        auto_focus_sidebar = true;
        enable_token_counting = true;
      };

      # width is a percentage to avante and columns to the registry; filled
      # in at setup from the editor width.
      windows = {
        position = registry.ui.panel.position;
        wrap = true;
        sidebar_header = {
          enabled = true;
          align = "center";
          rounded = true;
        };
        edit.start_insert = true;
        ask = {
          floating = false;
          start_insert = true;
        };
      };

      selector.provider = "telescope";
      input.provider = "dressing";

      # auto_set_keymaps is off; these only make avante's hints name the
      # keys that actually work.
      mappings = {
        ask = "<leader>aa";
        new_ask = "<leader>an";
        edit = "<leader>ae";
        refresh = "<leader>ar";
        focus = "<leader>af";
        stop = "<leader>ax";
        select_model = "<leader>aM";
        select_history = "<leader>ah";
        zen_mode = "<leader>az";
        toggle = {
          default = "<leader>aa";
          repomap = "<leader>aR";
        };
        files = {
          add_current = "<leader>ab";
          add_all_buffers = "<leader>aB";
        };
      };

      acp_providers = {
        claude-code = {
          command = "claude-agent-acp";
          args = [];
        };
        opencode = {
          command = "opencode";
          args = ["acp"];
        };
      };

      # Inline edit has to reproduce the selection verbatim; at avante's
      # default 0.75 a small model drifts (renames, drops a body).
      providers.ollama = {
        endpoint = registry.endpoints.ollama.url;
        extra_request_body.options.temperature = 0.1;
      };

      providers.opencode-go = {
        __inherited_from = "openai";
        display_name = "OpenCode Go";
        endpoint = "${go.url}/v1";
        api_key_name = registry.auth.${go.auth}.env;
        extra_headers.__raw = ''require("ai.opencode").headers("avante")'';
        # Go fronts many vendors' models and the openai defaults this inherits
        # (temperature 0.75, reasoning_effort) are not universal: Kimi K2.7
        # rejects any temperature but 1. Leave sampling to each model.
        parse_curl_args.__raw = ''
          function(self, prompt_opts)
            local out = require("avante.providers.openai").parse_curl_args(self, prompt_opts)
            if out and out.body then
              out.body.temperature = nil
              out.body.reasoning_effort = nil
            end
            return out
          end
        '';
      };
    };
  };

  # avante's plugin/avante.lua defines every :Avante* command at startup,
  # guarded by this flag. Holding it means no backend, no commands: the file
  # is sourced from ai.avante once setup has run.
  extraConfigLuaPre = ''
    vim.g.avante_loaded = 1
  '';

  extraConfigLua = ''
    package.preload["ai.avante"] = function()
      local M = {}
      local did_setup = false

      local function role()
        return require("ai").role("agent")
      end

      local function width_pct()
        local cols = ${toString registry.ui.panel.width} * 100 / vim.o.columns
        return math.min(80, math.max(20, math.floor(cols)))
      end

      --- The part of avante's config that follows the role: which provider,
      --- and how the model reaches it. ACP agents read it from the
      --- environment they are spawned with, so a change lands on the next
      --- chat; the HTTP provider reads it per request.
      local function patch(r)
        local p = {provider = r.backend, acp_providers = {}, providers = {}}
        if r.backend == "claude-code" then
          p.acp_providers["claude-code"] = {env = {ANTHROPIC_MODEL = r.model}}
        elseif r.backend == "opencode" then
          local content = r.model and vim.json.encode({model = r.model}) or nil
          p.acp_providers.opencode = {env = {OPENCODE_CONFIG_CONTENT = content}}
        elseif r.transport == "http" then
          p.providers[r.backend] = {model = r.model}
        end
        return p
      end

      local function credentials(r)
        if r.auth then
          require("ai.auth").export(r.auth)
        end
      end

      function M.ready()
        local r = role()
        return r ~= nil and r.backend ~= nil
      end

      --- avante restores whatever model it used last over the configured
      --- one, and a provider it has already built keeps the model it was
      --- built with; the registry is the authority on both.
      local function assert_model(r)
        if not r.backend or require("avante.config").acp_providers[r.backend] then
          return
        end
        local functor = rawget(require("avante.providers"), r.backend)
        if functor then
          functor.model = r.model
        end
      end

      --- Inline edit replaces the selection with what the reply wraps in
      --- <code>. An ACP agent answers as an agent, prose and tool calls, so
      --- Edit runs on the `edit` role instead: an HTTP model, local ollama
      --- by default, swapped in for the life of the prompt.
      local function edit_patch(e)
        if not (e and e.backend and e.model and e.transport ~= "acp") then
          return nil
        end
        local p = {providers = {}}
        p.providers[e.backend] = {model = e.model}
        return p
      end

      local agent_provider = nil

      function M.restore_provider()
        if agent_provider then
          require("avante.config").override({provider = agent_provider})
          agent_provider = nil
        end
      end

      --- Set avante up for the current agent role. False while the role has
      --- no backend: until then no :Avante* command exists.
      function M.ensure()
        local r = role()
        if not (r and r.backend) then
          return false
        end
        if did_setup then
          return true
        end
        credentials(r)
        require("avante_lib").load()
        local opts = ${lib.nixvim.toLuaObject config.plugins.avante.settings}
        opts.windows.width = width_pct()
        opts = vim.tbl_deep_extend("force", opts, patch(r))
        local ep = edit_patch(require("ai").role("edit"))
        if ep then
          opts = vim.tbl_deep_extend("force", opts, ep)
        end
        require("avante").setup(opts)
        vim.g.avante_loaded = nil
        vim.cmd("runtime! plugin/avante.lua")
        did_setup = true
        assert_model(r)
        -- The prompt closing, sent or cancelled, hands the sidebar back to
        -- the agent provider.
        local Selection = require("avante.selection")
        local close = Selection.close_editing_input
        Selection.close_editing_input = function(self, ...)
          M.restore_provider()
          return close(self, ...)
        end
        return true
      end

      --- Inline edit of lines first..last on the `edit` role's provider,
      --- or the agent's own when that role names none.
      function M.edit(first, last)
        if not M.ensure() then
          return false
        end
        -- Open first: creating the prompt closes any previous one, and that
        -- close hands the provider back. The swap holds until this prompt
        -- closes in turn; the request reads the provider when submitted.
        require("avante.api").edit(nil, first, last)
        local e = require("ai").role("edit")
        local Config = require("avante.config")
        local ep = edit_patch(e)
        local _, selection = require("avante").get()
        if ep and selection and selection.prompt_input and e.backend ~= Config.provider then
          credentials(e)
          Config.override(ep)
          assert_model(e)
          agent_provider = Config.provider
          Config.override({provider = e.backend})
        end
        return true
      end

      --- Text into the sidebar's input, unsent, with the files it names
      --- attached to the context -- the way sidekick's {quickfix} lands in a
      --- terminal prompt: you finish the sentence and submit.
      function M.stage(text, files)
        if not M.ensure() then
          return false
        end
        local avante = require("avante")
        avante.open_sidebar({})
        local sidebar = avante.get()
        if not sidebar then
          return false
        end
        for _, f in ipairs(files or {}) do
          pcall(require("avante.api").add_selected_file, f)
        end
        local existing = sidebar:get_input_value()
        sidebar:set_input_value((existing ~= "" and (existing .. "\n\n") or "") .. text .. "\n")
        sidebar:focus_input()
        pcall(function()
          local buf = sidebar.containers.input.bufnr
          vim.api.nvim_win_set_cursor(sidebar.containers.input.winid, {vim.api.nvim_buf_line_count(buf), 0})
        end)
        return true
      end

      --- Registry -> avante for the edit role.
      function M.apply_edit(e)
        local ep = edit_patch(e)
        if did_setup and ep then
          require("avante.config").override(ep)
          assert_model(e)
        end
      end

      --- Registry -> avante, for a change after setup.
      function M.apply(r)
        r = r or role()
        if not (r and r.backend) then
          return false
        end
        if not did_setup then
          return M.ensure()
        end
        credentials(r)
        local Config = require("avante.config")
        if agent_provider then
          agent_provider = r.backend
        end
        local switching = Config.provider ~= r.backend
        Config.override(patch(r))
        assert_model(r)
        if switching then
          require("avante.api").switch_provider(r.backend)
        elseif r.transport == "acp" and r.model then
          vim.notify("ai: agent model " .. r.model .. " applies to the next chat (<leader>an)", vim.log.levels.INFO)
        end
        return true
      end

      return M
    end

    require("ai").on_change(function(name, r)
      if name == "agent" then
        require("ai.avante").apply(r)
      elseif name == "edit" then
        require("ai.avante").apply_edit(r)
      end
    end)
  '';
}
