# minuet-ai.nvim — LLM completions in the nvim-cmp menu, alongside LSP items.
#
# Completions arrive as ordinary cmp candidates, so gopls and the model share
# one popup and one accept key. Runs against a local Ollama FIM model by
# default. Projects override the model from a .nvim.lua via the
# `minuet-project` Lua module defined below.
{...}: let
  registry = import ../ai/registry.nix;
  role = n: registry.roles.${n};
  url = n: registry.endpoints.${(role n).endpoint};
  key = n: {__raw = "function() return require('ai.auth').get('${(role n).auth}') end";};

  opencodeGoDuet = {
    name = "OpenCode Go";
    end_point = "${url "next-edit-remote"}/v1/chat/completions";
    api_key = key "next-edit-remote";
    model = "${(role "next-edit-remote").model}";
    request_timeout = 20;
    transform = [
      {
        __raw = ''
          function(data)
            data.headers = vim.tbl_extend("force", data.headers, require("minuet-opencode").headers("next-edit"))
            return data
          end
        '';
      }
    ];
  };

  ollamaDuet = {
    name = "Ollama";
    end_point = "${url "next-edit"}/v1/chat/completions";
    api_key = key "next-edit";
    model = "${(role "next-edit").model}";
    request_timeout = 180;
    transform = [];
  };
in {
  plugins.minuet = {
    enable = true;

    settings = {
      provider = "openai_fim_compatible";
      n_completions = 2;
      context_window = 2048;
      request_timeout = 10;
      throttle = 1000;
      debounce = 300;
      notify = "warn";

      # Off until <leader>ii. Manual <C-Space> still reaches the model.
      cmp.enable_auto_complete = false;
      blink.enable_auto_complete = false;

      provider_options = {
        openai_fim_compatible = {
          name = "Ollama";
          end_point = "${url "completion"}/v1/completions";
          api_key = key "completion";
          model = "${(role "completion").model}";
          stream = true;
          optional = {
            max_tokens = 56;
            top_p = 0.9;
            stop = [
              "<|endoftext|>"
              "<|fim_prefix|>"
              "<|fim_middle|>"
              "<|fim_suffix|>"
              "<|fim_pad|>"
              "<|repo_name|>"
              "<|file_sep|>"
            ];
          };
          template = {
            suffix = false;
            # The language/indentation preamble is load-bearing: without it the
            # 1.5b model ignores the FIM boundary and runs on past the middle.
            prompt.__raw = ''
              function(pre, suf, _)
                local utils = require("minuet.utils")
                local preamble = utils.add_language_comment() .. "\n" .. utils.add_tab_comment() .. "\n"
                return "<|fim_prefix|>" .. preamble .. pre .. "<|fim_suffix|>" .. suf .. "<|fim_middle|>"
              end
            '';
          };
        };

        openai_compatible = {
          name = "OpenCode Go";
          end_point = "${url "completion-remote"}/v1/chat/completions";
          api_key = key "completion-remote";
          model = "${(role "completion-remote").model}";
          stream = true;
          transform = [
            {
              __raw = ''
                function(data)
                  data.headers = vim.tbl_extend("force", data.headers, require("minuet-opencode").headers("completion"))
                  return data
                end
              '';
            }
          ];
        };
      };

      presets = {
        fast = {
          provider = "openai_fim_compatible";
          provider_options.openai_fim_compatible.model = "${(role "completion").model}";
          context_window = 1024;
          request_timeout = 10;
        };
        big = {
          provider = "openai_fim_compatible";
          provider_options.openai_fim_compatible.model = "${registry.tiers.big.completion.model}";
          context_window = 4096;
          request_timeout = 20;
        };
        go = {
          provider = "openai_compatible";
          context_window = 8000;
          request_timeout = 15;
        };
      };

      # Both alternative frontends stay off: cmp is the one menu. minuet's own
      # LSP client would reach cmp a second time through cmp-nvim-lsp.
      virtualtext.auto_trigger_ft = [];
      lsp.enabled_ft = [];
      lsp.inline_completion.enable = false;

      # Duet (next-edit prediction) rewrites a whole region. Only
      # `openai_compatible` is a real backend slot; `go` and `ollama` are inert
      # templates that minuet-project swaps into it at runtime. The slot holds
      # the local backend by default -- the remote one needs a credential that
      # may not be present.
      duet = {
        provider = "openai_compatible";
        request_timeout = 20;
        provider_options = {
          openai_compatible = ollamaDuet;
          go = opencodeGoDuet;
          ollama = ollamaDuet;
        };
      };
    };
  };

  extraConfigLua = ''
    -- minuet-opencode: headers OpenCode Go requires of third-party clients.
    -- Requests without x-opencode-session are rejected with a 400
    -- MissingSessionID. See https://opencode.ai/docs/go/#where-can-i-use-it
    package.preload["minuet-opencode"] = function()
      local M = {}

      local session = ("nvim-%d-%d"):format(vim.fn.getpid(), os.time())

      --- Headers for one request kind; the session id is stable per Neovim process.
      function M.headers(kind)
        return {
          ["x-opencode-session"] = session .. "-" .. (kind or "main"),
          ["User-Agent"] = "minuet.nvim-nixvim/1.0",
        }
      end

      return M
    end

    -- minuet-models: live model picker. Both backends expose an
    -- OpenAI-compatible /v1/models, so one code path serves Ollama and
    -- OpenCode Go; minuet's own :Minuet change_model only knows its built-in
    -- modelcard and lists nothing for either of them.
    package.preload["minuet-models"] = function()
      local M = {}

      local function models_url(end_point)
        return (end_point:gsub("/chat/completions$", "/models"):gsub("/v1/completions$", "/v1/models"))
      end

      local function request_headers(opts)
        local headers = {}
        local key = require("minuet.utils").get_api_key(opts.api_key)
        if key then
          headers["Authorization"] = "Bearer " .. key
        end
        if opts.end_point:find("opencode.ai", 1, true) then
          headers = vim.tbl_extend("force", headers, require("minuet-opencode").headers("models"))
        end
        return headers
      end

      local function fetch(opts, on_models)
        local cmd = { "curl", "-s", "--max-time", "15", models_url(opts.end_point) }
        for name, value in pairs(request_headers(opts)) do
          table.insert(cmd, "-H")
          table.insert(cmd, name .. ": " .. value)
        end

        vim.system(cmd, { text = true }, function(out)
          vim.schedule(function()
            local ok, decoded = pcall(vim.json.decode, out.stdout or "")
            if not ok or type(decoded) ~= "table" or not decoded.data then
              vim.notify("Could not list models from " .. opts.name, vim.log.levels.ERROR)
              return
            end

            local models = vim.tbl_map(function(entry)
              return entry.id
            end, decoded.data)
            table.sort(models)
            on_models(models)
          end)
        end)
      end

      --- Backends offered for a target, as display name -> config key.
      local function backends(target)
        local minuet = require("minuet")
        local labels, keys = {}, {}

        if target == "next-edit" then
          for _, key in ipairs(require("minuet-project").duet_backends) do
            local name = minuet.config.duet.provider_options[key].name
            table.insert(labels, name)
            keys[name] = key
          end
        else
          for key, opts in pairs(minuet.config.provider_options) do
            if opts.name then
              table.insert(labels, opts.name)
              keys[opts.name] = key
            end
          end
        end

        table.sort(labels)
        return labels, keys
      end

      --- Pick the backend for "completion" (default) or "next-edit", then its model.
      function M.choose(target)
        local labels, keys = backends(target)

        vim.ui.select(labels, {
          prompt = (target == "next-edit" and "Duet" or "Completion") .. " backend:",
        }, function(label)
          if not label then
            return
          end

          if target == "next-edit" then
            require("minuet-project").duet_backend(keys[label])
          else
            require("minuet").change_provider(keys[label])
          end

          M.pick(target)
        end)
      end

      --- Pick a model for "completion" (default) or "next-edit" from the live provider.
      function M.pick(target)
        local minuet = require("minuet")
        local scope = target == "next-edit" and minuet.config.duet or minuet.config
        local opts = scope.provider_options[scope.provider]

        fetch(opts, function(models)
          vim.ui.select(models, {
            prompt = ("%s model (%s):"):format(target == "next-edit" and "Duet" or "Completion", opts.name),
          }, function(choice)
            if not choice then
              return
            end
            opts.model = choice
            vim.notify(("%s model set to %s"):format(opts.name, choice), vim.log.levels.INFO)
          end)
        end)
      end

      return M
    end

    -- Statusline indicator: empty while AI completion is off, otherwise the
    -- active model plus a spinner for in-flight requests.
    do
      local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
      local in_flight, frame = 0, 1
      local group = vim.api.nvim_create_augroup("MinuetStatus", { clear = true })

      vim.api.nvim_create_autocmd("User", {
        pattern = "MinuetRequestStarted",
        group = group,
        callback = function()
          in_flight = in_flight + 1
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        pattern = "MinuetRequestFinished",
        group = group,
        callback = function()
          in_flight = math.max(0, in_flight - 1)
        end,
      })

      function _G.minuet_lualine()
        local ok, minuet = pcall(require, "minuet")
        if not ok or not minuet.config or not minuet.config.cmp.enable_auto_complete then
          return ""
        end

        local opts = minuet.config.provider_options[minuet.config.provider]
        local label = "AI " .. (opts.model or "?")

        if in_flight > 0 then
          frame = frame % #spinner + 1
          return label .. " " .. spinner[frame]
        end

        return label
      end
    end

    -- minuet-project: per-project minuet control, callable from .nvim.lua
    package.preload["minuet-project"] = function()
      local M = {}

      local function config()
        return require("minuet").config
      end

      --- Apply a preset defined in minuet.nix ("fast", "big", "go").
      function M.preset(name)
        require("minuet").change_preset(name)
      end

      --- Set the Ollama model used for FIM completion. Routed through the
      --- registry so :AiStatus stays truthful; the listener below writes it
      --- into minuet's live config.
      function M.model(name)
        require("ai").set("completion", name)
      end

      --- Route completions through the remote OpenCode Go endpoint.
      function M.remote()
        require("minuet").change_provider("openai_compatible")
      end

      --- Route completions back through local Ollama.
      function M.localhost()
        require("minuet").change_provider("openai_fim_compatible")
      end

      local function redraw_statusline()
        pcall(function()
          require("lualine").refresh()
        end)
      end

      --- Let the model contribute to the cmp menu as you type.
      function M.auto(enabled)
        config().cmp.enable_auto_complete = enabled ~= false
        redraw_statusline()
      end

      --- Keep the model out of the menu until <C-Space>.
      function M.manual()
        config().cmp.enable_auto_complete = false
        redraw_statusline()
      end

      --- Flip AI candidates in the cmp menu.
      function M.toggle()
        local cmp = config().cmp
        cmp.enable_auto_complete = not cmp.enable_auto_complete
        redraw_statusline()
        vim.notify("Minuet completions " .. (cmp.enable_auto_complete and "on" or "off"), vim.log.levels.INFO)
      end

      local tunables = {
        "context_window",
        "request_timeout",
        "n_completions",
        "debounce",
        "throttle",
      }

      --- One-shot project setup: { preset, model, remote, auto, <tunables> }.
      function M.setup(opts)
        opts = opts or {}

        if opts.preset then
          M.preset(opts.preset)
        end
        if opts.remote then
          M.remote()
        end
        if opts.duet then
          M.duet_backend(opts.duet)
        end
        if opts.model then
          M.localhost()
          M.model(opts.model)
        end

        for _, key in ipairs(tunables) do
          if opts[key] then
            config()[key] = opts[key]
          end
        end

        if opts.auto ~= nil then
          M.auto(opts.auto)
        end
      end

      --- Point duet's next-edit prediction at a provider.
      function M.duet_provider(name)
        config().duet.provider = name
      end

      --- Set the model duet's current provider uses.
      function M.duet_model(name)
        require("ai").set("next-edit", name)
      end

      M.duet_backends = { "go", "ollama" }

      local duet_active = "go"
      local duet_defaults

      --- Swap duet between the configured backends ("go", "ollama").
      --- Only the connection fields move; the prompt templates minuet ships
      --- with stay in place, and each backend keeps its own model choice.
      function M.duet_backend(name)
        local duet = config().duet
        local slots = duet.provider_options

        if not slots[name] then
          vim.notify("Unknown duet backend: " .. tostring(name), vim.log.levels.ERROR)
          return
        end

        duet_defaults = duet_defaults or vim.deepcopy(slots.openai_compatible)
        slots[duet_active].model = slots.openai_compatible.model

        local merged = vim.deepcopy(duet_defaults)
        for _, field in ipairs({ "name", "end_point", "api_key", "model", "optional" }) do
          if slots[name][field] ~= nil then
            merged[field] = vim.deepcopy(slots[name][field])
          end
        end
        merged.transform = vim.deepcopy(slots[name].transform or {})

        slots.openai_compatible = merged
        duet.request_timeout = slots[name].request_timeout or duet.request_timeout
        duet_active = name

        vim.notify("Duet backend: " .. merged.name .. " / " .. merged.model, vim.log.levels.INFO)
      end

      --- Echo which backends are live, for both completion and duet.
      function M.status()
        local c = config()
        local provider = c.provider
        local completion = c.provider_options[provider]
        local duet = c.duet.provider_options[c.duet.provider]

        vim.notify(table.concat({
          ("completion : %s / %s"):format(completion.name or provider, completion.model),
          ("duet       : %s / %s"):format(duet.name or c.duet.provider, duet.model),
          ("in menu    : %s"):format(c.cmp.enable_auto_complete and "as you type" or "<C-Space> only"),
        }, "\n"), vim.log.levels.INFO, { title = "Minuet" })
      end

      return M
    end

    -- Registry -> minuet. minuet re-reads its config table on every request,
    -- so writing here takes effect on the next completion with no restart.
    -- Runs once per role at startup too, which is what applies NVIM_AI_TIER.
    do
      local ai = require("ai")
      local function apply(name, r)
        -- Every role handled here is HTTP; a nil url means someone repointed
        -- it at an ACP/CLI backend, which minuet cannot drive.
        if not (r and r.url) then
          return
        end
        local cfg = require("minuet").config
        if name == "completion" then
          cfg.provider_options.openai_fim_compatible.model = r.model
          cfg.provider_options.openai_fim_compatible.end_point = r.url .. "/v1/completions"
        elseif name == "completion-remote" then
          cfg.provider_options.openai_compatible.model = r.model
          cfg.provider_options.openai_compatible.end_point = r.url .. "/v1/chat/completions"
        elseif name == "next-edit" then
          local slot = cfg.duet.provider_options[cfg.duet.provider]
          if slot then
            slot.model = r.model
            slot.end_point = r.url .. "/v1/chat/completions"
          end
        end
        pcall(function()
          require("lualine").refresh()
        end)
      end
      ai.on_change(apply)
      for _, name in ipairs({"completion", "completion-remote", "next-edit"}) do
        apply(name, ai.role(name))
      end
    end
  '';
}
