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
  imports = [./actions.nix ./progress.nix];

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
          requires = true,
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
          local ep = r.endpoint and registry.endpoints[r.endpoint] or nil
          r.url = ep and ep.url or nil
          r.auth = ep and ep.auth or nil
          r.api_key = r.auth and auth.fn(r.auth) or nil
          r.source = M.source(name)
          return r
        end

        M.get = M.role

        function M.endpoints()
          local names = vim.tbl_keys(registry.endpoints)
          table.sort(names)
          return names
        end

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
          if spec.model then
            M.check(name, function(problems)
              if #problems > 0 then
                vim.notify(
                  ("ai: %s cannot serve %s -- %s"):format(spec.model, name, table.concat(problems, ", ")),
                  vim.log.levels.WARN
                )
              end
            end)
          end
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
              endpoint = r.endpoint or r.backend or r.command,
              backend = r.backend or r.command or "-",
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

        --- Capabilities ollama reports for a model, cached per model.
        --- Only ollama exposes this; other endpoints return nil, meaning
        --- "unknown" rather than "unsupported".
        local caps_cache = {}
        function M.capabilities(name, cb)
          local r = M.role(name)
          if not (r and r.url and r.endpoint == "ollama" and r.model) then
            return cb(nil)
          end
          if caps_cache[r.model] then
            return cb(caps_cache[r.model])
          end
          vim.system({
            "curl",
            "-s",
            "--max-time",
            "10",
            r.url .. "/api/show",
            "-d",
            vim.json.encode({model = r.model}),
          }, {text = true}, function(obj)
            vim.schedule(function()
              local ok, parsed = pcall(vim.json.decode, obj.stdout or "")
              local caps = ok and type(parsed) == "table" and parsed.capabilities or nil
              if caps then
                caps_cache[r.model] = caps
              end
              cb(caps)
            end)
          end)
        end

        --- Check a role's model against its declared `requires`.
        --- Calls back with a list of problems; empty means it checks out.
        function M.check(name, cb)
          local r = M.role(name)
          if not r then
            return cb({"unknown role"})
          end
          local need = r.requires or {}
          if #need == 0 then
            return cb({})
          end
          M.capabilities(name, function(caps)
            if not caps then
              return cb({}, "not checkable")
            end
            local has = {}
            for _, c in ipairs(caps) do
              has[c] = true
            end
            -- A base model reports nothing beyond these two.
            local instruct = false
            for _, c in ipairs(caps) do
              if c ~= "completion" and c ~= "insert" then
                instruct = true
              end
            end
            local problems = {}
            for _, want in ipairs(need) do
              if want == "instruct" then
                if not instruct then
                  table.insert(problems, "not instruction-following (base model)")
                end
              elseif not has[want] then
                table.insert(problems, "lacks " .. want)
              end
            end
            cb(problems, table.concat(caps, ","))
          end)
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

      -- Statusline. One segment per role: what tool, which provider, which
      -- model -- plus a spinner on whichever is working right now.
      --
      -- Segments are separate lualine components (see lualine.nix) so each
      -- gets its own colour without embedding highlight escapes in a string.
      local LABEL = {
        completion = "cmp",
        ["next-edit"] = "next",
        edit = "edit",
        ask = "ask",
        agent = "agent",
      }

      --- Width each segment needs, so narrow windows drop the least useful
      --- ones instead of wrapping.
      local PRIORITY = {"edit", "ask", "completion", "next-edit", "agent"}

      _G.ai_lualine_role = function(name)
        local ok, ai = pcall(require, "ai")
        if not ok then
          return ""
        end
        local r = ai.role(name)
        if not r then
          return ""
        end
        local provider = r.endpoint or r.backend or r.command or "?"
        local model = (r.model or "?"):gsub("^.-/", "")
        local spin = ""
        local okp, progress = pcall(require, "ai.progress")
        if okp and progress.running(name) then
          spin = progress.frame() .. " "
        end
        return string.format("%s%s %s/%s", spin, LABEL[name] or name, provider, model)
      end

      --- Which segments fit right now. Packed by real rendered width rather
      --- than a per-segment guess, so a wide statusline cannot overflow into
      --- the branch and location on the other side. A working role is always
      --- included, even when nothing else fits.
      local RESERVE = 60

      local function fitting()
        local budget = vim.o.columns - RESERVE
        local chosen, used = {}, 0
        local okp, progress = pcall(require, "ai.progress")
        local function width(name)
          return vim.fn.strdisplaywidth(_G.ai_lualine_role(name)) + 2
        end
        if okp then
          for _, name in ipairs(PRIORITY) do
            if progress.running(name) then
              chosen[name] = true
              used = used + width(name)
            end
          end
        end
        for _, name in ipairs(PRIORITY) do
          if not chosen[name] then
            local w = width(name)
            if used + w <= budget then
              chosen[name] = true
              used = used + w
            end
          end
        end
        return chosen
      end

      _G.ai_lualine_show = function(name)
        return fitting()[name] == true
      end

      --- Accent the working segment; dim completion when it is switched off.
      _G.ai_lualine_color = function(name)
        local okp, progress = pcall(require, "ai.progress")
        if okp and progress.running(name) then
          return {fg = "#fabd2f", gui = "bold"}
        end
        if name == "completion" then
          local okm, minuet = pcall(require, "minuet")
          if okm and minuet.config and minuet.config.cmp and not minuet.config.cmp.enable_auto_complete then
            return {fg = "#665c54"}
          end
        end
        return {fg = "#8ec07c"}
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
            "  %-12s %-26s %-12s %-12s %-11s %s",
            r.role,
            tostring(r.model),
            tostring(r.endpoint),
            tostring(r.backend),
            tostring(r.auth or "-"),
            r.source
          )
        )
      end
      show(
        string.format("  %-12s %-26s %-12s %-12s %-11s %s", "ROLE", "MODEL", "ENDPOINT", "BACKEND", "AUTH", "SOURCE"),
        lines
      )
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

    vim.api.nvim_create_user_command("AiDoctor", function()
      local ai = require("ai")
      local auth = require("ai.auth")
      local roles = ai.roles()
      local rows, pending = {}, #roles
      local resolved = {}
      for _, a in ipairs(auth.status(false)) do
        resolved[a.name] = a.resolved
      end
      for _, name in ipairs(roles) do
        ai.check(name, function(problems, caps)
          local r = ai.role(name)
          local verdict
          if #problems > 0 then
            verdict = "FAIL  " .. table.concat(problems, ", ")
          elseif r.auth and not resolved[r.auth] and r.endpoint ~= "ollama" then
            verdict = "AUTH  no credential for " .. r.auth
          elseif caps == "not checkable" or not caps then
            verdict = "ok    (capabilities not reported)"
          else
            verdict = "ok    " .. caps
          end
          table.insert(rows, string.format("  %-18s %-26s %s", name, tostring(r.model), verdict))
          pending = pending - 1
          if pending == 0 then
            table.sort(rows)
            show(string.format("  %-18s %-26s %s", "ROLE", "MODEL", "VERDICT"), rows)
          end
        end)
      end
    end, {desc = "AI: check every role's model against what the role needs"})

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
