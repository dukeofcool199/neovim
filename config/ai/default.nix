# Bakes config/ai/registry.nix into two requireable Lua modules:
#
#   ai.auth - credential resolution (env var first, `pass` on a miss, cached)
#   ai      - role -> model bindings, runtime overrides, change propagation
#
# Emitted into extraConfigLuaPre because nixvim assembles
# Pre -> Vim -> Lua -> Post and plugin setup() calls land in the Lua region;
# a preload registered there would come too late for eager consumers.
{...}: let
  registry = import ./registry.nix;
  registryJson = builtins.toJSON registry;
in {
  imports = [./actions.nix];

  extraConfigLuaPre = ''
    do
      local registry = vim.json.decode([==[${registryJson}]==])

      package.preload["ai.auth"] = function()
        local M = {}
        local cache = {}

        local function resolve(name, probe_pass)
          local spec = registry.auth[name]
          if not spec then
            return {source = "unknown"}
          end
          if spec.kind == "static" then
            return {value = spec.value, source = "static"}
          end
          if spec.kind == "none" then
            return {source = "none"}
          end
          if spec.env then
            local v = vim.env[spec.env]
            if type(v) == "string" and v ~= "" then
              return {value = v, source = "env"}
            end
          end
          if spec.pass and probe_pass ~= false then
            local ok, obj = pcall(function()
              return vim.system({"pass", "show", spec.pass}, {text = true}):wait()
            end)
            if ok and obj.code == 0 then
              local line = vim.split(obj.stdout or "", "\n", {trimempty = true})[1]
              if line and line ~= "" then
                return {value = vim.trim(line), source = "pass"}
              end
            end
          end
          return {source = "missing"}
        end

        --- Resolved credential for an identity, or nil. Cached per session.
        function M.get(name)
          local hit = cache[name]
          if hit == nil then
            hit = resolve(name, true)
            cache[name] = hit
          end
          return hit.value
        end

        --- Lazy thunk. The shape minuet and codecompanion want: they call it
        --- per request, so `pass` runs on first use rather than at startup.
        function M.fn(name)
          return function()
            return M.get(name)
          end
        end

        --- Eager export into vim.env, for consumers that only read the
        --- environment (sidekick snapshots it when it spawns a terminal).
        function M.export(name)
          local spec = registry.auth[name]
          if not (spec and spec.env) then
            return nil
          end
          local v = M.get(name)
          if v then
            vim.env[spec.env] = v
          end
          return v
        end

        function M.clear(name)
          if name then
            cache[name] = nil
          else
            cache = {}
          end
        end

        --- Never returns key material. Without `probe`, only free sources
        --- (env, static, cache) are consulted so no GPG prompt can fire.
        function M.status(probe)
          local out = {}
          for name, spec in pairs(registry.auth) do
            local hit = cache[name] or resolve(name, probe == true)
            if probe == true then
              cache[name] = hit
            end
            table.insert(out, {
              name = name,
              kind = spec.kind,
              env = spec.env,
              pass = spec.pass,
              resolved = hit.value ~= nil,
              source = hit.source,
            })
          end
          table.sort(out, function(a, b)
            return a.name < b.name
          end)
          return out
        end

        return M
      end

      package.preload["ai"] = function()
        local M = {}
        local auth = require("ai.auth")
        local overrides = {project = {}, session = {}}
        local tier = vim.env.NVIM_AI_TIER
        local listeners = {}
        local model_cache = {}

        local FIELDS = {
          model = true,
          backend = true,
          endpoint = true,
          auth = true,
          command = true,
        }

        local function tier_spec(role)
          local t = tier and registry.tiers and registry.tiers[tier]
          return t and t[role] or nil
        end

        --- Which layer supplied the current value.
        function M.source(role)
          if overrides.session[role] then
            return "session"
          end
          if overrides.project[role] then
            return "project"
          end
          if tier_spec(role) then
            return "tier:" .. tier
          end
          return "default"
        end

        --- Fully resolved role: registry -> tier -> project -> session.
        function M.role(name)
          local r = registry.roles[name]
          if not r then
            return nil
          end
          r = vim.deepcopy(r)
          -- Appended one at a time on purpose: ipairs over a literal holding
          -- a nil stops at the gap, which silently drops later layers.
          local layers = {}
          local function push(layer)
            if layer then
              table.insert(layers, layer)
            end
          end
          push(tier_spec(name))
          push(overrides.project[name])
          push(overrides.session[name])
          for _, layer in ipairs(layers) do
            r = vim.tbl_extend("force", r, layer)
          end
          r.name = name
          r.url = r.endpoint and registry.endpoints[r.endpoint] or nil
          r.api_key = r.auth and auth.fn(r.auth) or nil
          r.source = M.source(name)
          return r
        end

        M.get = M.role

        function M.roles()
          local names = vim.tbl_keys(registry.roles)
          table.sort(names)
          return names
        end

        function M.on_change(cb)
          table.insert(listeners, cb)
        end

        function M.emit(name)
          for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, name, M.role(name))
            if not ok then
              vim.notify("ai: listener failed: " .. tostring(err), vim.log.levels.WARN)
            end
          end
        end

        local function emit_all()
          for _, name in ipairs(M.roles()) do
            M.emit(name)
          end
        end

        --- Override a role. `spec` may be a bare model string.
        function M.set(name, spec, layer)
          layer = layer or "session"
          if not registry.roles[name] then
            vim.notify("ai: unknown role '" .. tostring(name) .. "'", vim.log.levels.WARN)
            return nil
          end
          if type(spec) == "string" then
            spec = {model = spec}
          end
          if type(spec) ~= "table" then
            vim.notify("ai.set: expected a table or string", vim.log.levels.WARN)
            return nil
          end
          for k in pairs(spec) do
            if not FIELDS[k] then
              vim.notify("ai.set: unknown field '" .. tostring(k) .. "'", vim.log.levels.WARN)
            end
          end
          overrides[layer][name] = vim.tbl_extend("force", overrides[layer][name] or {}, spec)
          M.emit(name)
          return M.role(name)
        end

        --- Project entry point, for .nvim.lua. Warns rather than errors so a
        --- typo in a project file never breaks startup.
        function M.setup(opts)
          if type(opts) ~= "table" then
            vim.notify("ai.setup: expected a table", vim.log.levels.WARN)
            return nil
          end
          for name, spec in pairs(opts) do
            M.set(name, spec, "project")
          end
          return M.status()
        end

        function M.reset(name)
          if name then
            overrides.session[name] = nil
            overrides.project[name] = nil
            M.emit(name)
          else
            overrides.session = {}
            overrides.project = {}
            emit_all()
          end
        end

        function M.tier(name)
          if name == nil or name == "" or name == "small" or name == "default" then
            tier = nil
          elseif registry.tiers and registry.tiers[name] then
            tier = name
          else
            vim.notify("ai: unknown tier '" .. tostring(name) .. "'", vim.log.levels.WARN)
            return nil
          end
          emit_all()
          return tier or "small"
        end

        function M.status()
          local out = {}
          for _, name in ipairs(M.roles()) do
            local r = M.role(name)
            table.insert(out, {
              role = name,
              model = r.model,
              backend = r.backend or r.command or r.endpoint,
              auth = r.auth,
              source = r.source,
            })
          end
          return out
        end

        --- Models a role can reach. HTTP endpoints serve /v1/models; ACP and
        --- CLI roles are enumerated by `opencode models`.
        function M.models(name, cb)
          local r = M.role(name)
          if not r then
            return cb({})
          end
          local key = r.url or r.backend or r.command or "?"
          if model_cache[key] then
            return cb(model_cache[key])
          end
          local function done(list)
            model_cache[key] = list
            cb(list)
          end
          if r.url then
            local cmd = {"curl", "-s", "--max-time", "10", r.url .. "/v1/models"}
            local k = r.api_key and r.api_key() or nil
            if k then
              table.insert(cmd, "-H")
              table.insert(cmd, "Authorization: Bearer " .. k)
            end
            vim.system(cmd, {text = true}, function(obj)
              vim.schedule(function()
                local ok, parsed = pcall(vim.json.decode, obj.stdout or "")
                local list = {}
                if ok and type(parsed) == "table" and parsed.data then
                  for _, m in ipairs(parsed.data) do
                    if m.id then
                      table.insert(list, m.id)
                    end
                  end
                end
                table.sort(list)
                done(list)
              end)
            end)
          else
            vim.system({"opencode", "models"}, {text = true}, function(obj)
              vim.schedule(function()
                done(vim.split(obj.stdout or "", "\n", {trimempty = true}))
              end)
            end)
          end
        end

        --- Synchronous view of the model cache, for command completion
        --- (completion callbacks cannot await). Warms the cache on a miss, so
        --- the first <Tab> may come back empty and the next one is populated.
        function M.models_cached(name)
          local r = M.role(name)
          if not r then
            return {}
          end
          local key = r.url or r.backend or r.command or "?"
          if not model_cache[key] then
            M.models(name, function() end)
            return {}
          end
          return model_cache[key]
        end

        local function select_from(list, prompt, on_choice)
          if #list == 0 then
            vim.notify("ai: no models available", vim.log.levels.WARN)
            return
          end
          local ok, pickers = pcall(require, "telescope.pickers")
          if not ok then
            vim.ui.select(list, {prompt = prompt}, function(choice)
              if choice then
                on_choice(choice)
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
              prompt_title = prompt,
              finder = finders.new_table({results = list}),
              sorter = conf.generic_sorter({}),
              attach_mappings = function(bufnr)
                actions.select_default:replace(function()
                  actions.close(bufnr)
                  local sel = action_state.get_selected_entry()
                  if sel then
                    on_choice(sel[1])
                  end
                end)
                return true
              end,
            })
            :find()
        end

        --- Pick a model for `name`, then run `cb` if given.
        function M.pick(name, cb)
          if not name then
            select_from(M.roles(), "ai: select role", function(role)
              M.pick(role, cb)
            end)
            return
          end
          M.models(name, function(list)
            select_from(list, "ai: model for " .. name, function(choice)
              M.set(name, choice)
              vim.notify("ai: " .. name .. " -> " .. choice)
              if cb then
                cb(choice)
              end
            end)
          end)
        end

        return M
      end

      --- Statusline: active completion and chat models, provider stripped.
      _G.ai_lualine = function()
        local ok, ai = pcall(require, "ai")
        if not ok then
          return ""
        end
        local function short(role)
          local r = ai.role(role)
          return r and (r.model or "?"):gsub("^.-/", "") or "?"
        end
        return string.format("󰚩 %s  %s", short("completion"), short("ask"))
      end
    end
  '';

  extraConfigLua = ''
    local function prefix_filter(list, lead)
      return vim.tbl_filter(function(x)
        return tostring(x):sub(1, #lead) == lead
      end, list)
    end

    local function role_or_model_complete(lead, cmdline)
      local ai = require("ai")
      local parts = vim.split(vim.trim(cmdline), "%s+")
      local given = #parts - 1
      local trailing = cmdline:match("%s$") ~= nil
      if given == 0 or (given == 1 and not trailing) then
        return prefix_filter(ai.roles(), lead)
      end
      return prefix_filter(ai.models_cached(parts[2]), lead)
    end

    local function show(title, lines)
      local out = {{title .. "\n", "Title"}}
      for _, l in ipairs(lines) do
        table.insert(out, {l .. "\n", "Normal"})
      end
      vim.api.nvim_echo(out, false, {})
    end

    vim.api.nvim_create_user_command("AiModel", function(o)
      local ai = require("ai")
      local role, model = o.fargs[1], o.fargs[2]
      if not role then
        return ai.pick()
      end
      if not model then
        return ai.pick(role)
      end
      local r = ai.set(role, model)
      if r then
        vim.notify("ai: " .. role .. " -> " .. tostring(r.model))
      end
    end, {nargs = "*", complete = role_or_model_complete, desc = "AI: set model for a role"})

    vim.api.nvim_create_user_command("AiPick", function(o)
      require("ai").pick(o.fargs[1])
    end, {
      nargs = "?",
      complete = function(lead)
        return prefix_filter(require("ai").roles(), lead)
      end,
      desc = "AI: pick role then model",
    })

    vim.api.nvim_create_user_command("AiBackend", function(o)
      local ai = require("ai")
      local role, backend = o.fargs[1], o.fargs[2]
      if not (role and backend) then
        return vim.notify("usage: AiBackend <role> <backend>", vim.log.levels.WARN)
      end
      local r = ai.set(role, {backend = backend})
      if r then
        vim.notify("ai: " .. role .. " backend -> " .. backend)
      end
    end, {
      nargs = "*",
      complete = function(lead, cmdline)
        local ai = require("ai")
        local parts = vim.split(vim.trim(cmdline), "%s+")
        local given = #parts - 1
        local trailing = cmdline:match("%s$") ~= nil
        if given == 0 or (given == 1 and not trailing) then
          return prefix_filter(ai.roles(), lead)
        end
        return prefix_filter({"ollama", "opencode", "opencode_go", "anthropic", "openrouter"}, lead)
      end,
      desc = "AI: repoint a role at another backend",
    })

    vim.api.nvim_create_user_command("AiStatus", function()
      local lines = {}
      for _, r in ipairs(require("ai").status()) do
        table.insert(
          lines,
          string.format(
            "  %-18s %-28s %-14s %-12s %s",
            r.role,
            tostring(r.model),
            tostring(r.backend),
            tostring(r.auth or "-"),
            r.source
          )
        )
      end
      show(string.format("  %-18s %-28s %-14s %-12s %s", "ROLE", "MODEL", "BACKEND", "AUTH", "SOURCE"), lines)
    end, {desc = "AI: role/model status"})

    vim.api.nvim_create_user_command("AiAuth", function(o)
      local auth = require("ai.auth")
      if o.bang then
        auth.clear(o.fargs[1])
      end
      local lines = {}
      for _, a in ipairs(auth.status(o.bang)) do
        if (not o.fargs[1]) or a.name == o.fargs[1] then
          table.insert(
            lines,
            string.format(
              "  %-14s %-8s %-24s %-8s %s",
              a.name,
              a.kind,
              tostring(a.env or "-"),
              a.resolved and "yes" or "no",
              a.source
            )
          )
        end
      end
      show(
        string.format("  %-14s %-8s %-24s %-8s %s", "IDENTITY", "KIND", "ENV", "OK", "SOURCE")
          .. (o.bang and "" or "   (! to probe pass)"),
        lines
      )
    end, {
      nargs = "?",
      bang = true,
      complete = function(lead)
        local names = {}
        for _, a in ipairs(require("ai.auth").status(false)) do
          table.insert(names, a.name)
        end
        return prefix_filter(names, lead)
      end,
      desc = "AI: credential status (! clears cache and probes pass)",
    })

    vim.api.nvim_create_user_command("AiTier", function(o)
      local t = require("ai").tier(o.fargs[1])
      if t then
        vim.notify("ai: tier -> " .. t)
      end
    end, {
      nargs = "?",
      complete = function(lead)
        return prefix_filter({"small", "big"}, lead)
      end,
      desc = "AI: switch model tier",
    })

    vim.api.nvim_create_user_command("AiReset", function(o)
      require("ai").reset(o.fargs[1])
      vim.notify("ai: reset " .. (o.fargs[1] or "all roles"))
    end, {
      nargs = "?",
      complete = function(lead)
        return prefix_filter(require("ai").roles(), lead)
      end,
      desc = "AI: drop session/project overrides",
    })
  '';
}
