# codecompanion.nvim — in-editor chat buffer and inline transforms.
#
# The chat window complements sidekick rather than duplicating it: this one is
# a native buffer with editor context (#buffer, #lsp, selections), sidekick is
# a real terminal running an agent CLI that edits files itself.
#
# Models and credentials come from config/ai/registry.nix.
{...}: let
  registry = import ../ai/registry.nix;
  role = n: registry.roles.${n};
  url = n: registry.endpoints.${(role n).endpoint};
in {
  plugins.codecompanion = {
    enable = true;

    settings = {
      display = {
        chat = {
          show_settings = false;
          # Same shape as the sidekick terminal: a fixed-width full-height
          # panel, not half the editor. width >= 1 is read as absolute
          # columns; the upstream default of 0.5 is a fraction.
          window = {
            layout = "vertical";
            position = registry.ui.panel.position;
            width = registry.ui.panel.width;
            full_height = true;
          };
        };
      };
      opts = {
        log_level = "TRACE";
        send_code = true;
        use_default_actions = true;
        use_default_prompts = true;
      };

      adapters = {
        # One declarative injection point for every HTTP adapter's credential.
        # Thunks, not "cmd:" strings: cmd: shells out on every request with a
        # 20s timeout, whereas ai.auth caches after the first resolution.
        http = {
          extend = {
            anthropic.env.api_key.__raw = "function() return require('ai.auth').get('anthropic') end";
            openrouter.env.api_key.__raw = "function() return require('ai.auth').get('openrouter') end";
            ollama = {
              env.url.__raw = "function() return '${url "edit"}' end";
              # Without this the adapter picks whatever ollama lists first and
              # the edit role's model is ignored.
              schema.model.default = "${(role "edit").model}";
            };
          };

          # ask-local needs a different model on the same endpoint, so it gets
          # its own adapter rather than fighting over `ollama`'s default.
          ollama_ask.__raw = ''
            function()
              return require("codecompanion.adapters").extend("ollama", {
                name = "ollama_ask",
                formatted_name = "Ollama (chat)",
                schema = {
                  model = {
                    default = "${(role "ask-local").model}",
                  },
                },
              })
            end
          '';

          # OpenCode Go over the openai_compatible shim. schema.model.default
          # must be a literal: the built-in default does a synchronous
          # /v1/models fetch and silently yields nil when that fails.
          opencode_go.__raw = ''
            function()
              return require("codecompanion.adapters").extend("openai_compatible", {
                name = "opencode_go",
                formatted_name = "OpenCode Go",
                env = {
                  api_key = function()
                    return require("ai.auth").get("opencode-go")
                  end,
                  url = "${url "completion-remote"}",
                  chat_url = "/v1/chat/completions",
                  models_endpoint = "/v1/models",
                },
                headers = {
                  ["Content-Type"] = "application/json",
                  Authorization = "Bearer ''${api_key}",
                  ["x-opencode-session"] = function()
                    return require("minuet-opencode").headers("codecompanion")["x-opencode-session"]
                  end,
                },
                schema = {
                  model = {
                    default = "${(role "completion-remote").model}",
                  },
                },
              })
            end
          '';
        };
      };

      interactions = {
        # opencode is an ACP adapter: it spawns `opencode acp` and authenticates
        # itself, so chat and agent need no credential from Neovim.
        agent = {
          adapter = "${(role "ask").backend}";
        };
        chat = {
          adapter = "${(role "ask").backend}";
        };
        # Inline needs an HTTP adapter; ACP cannot serve it. Local ollama by
        # default — the previous `copilot` had no credential on this machine.
        inline = {
          adapter = "${(role "edit").backend}";
        };
      };
    };
  };

  extraConfigLua = ''
    -- Registry -> codecompanion. Inline reads its adapter at construction, so
    -- a change lands on the next :CodeCompanion. Open chat buffers are
    -- retargeted directly via the chat API.
    do
      local ai = require("ai")
      local cc = require("codecompanion.config")

      ai.on_change(function(name, r)
        if not r then
          return
        end
        if name == "edit" then
          if r.backend then
            cc.interactions.inline.adapter = r.backend
          end
          if r.backend and r.model then
            -- Created on demand: a backend the registry did not ship with an
            -- extend entry (opencode_go, say) would otherwise drop the model.
            cc.adapters.http.extend = cc.adapters.http.extend or {}
            local entry = cc.adapters.http.extend[r.backend] or {}
            entry.schema = vim.tbl_deep_extend("force", entry.schema or {}, {
              model = {default = r.model},
            })
            cc.adapters.http.extend[r.backend] = entry
          end
        elseif name == "ask" then
          if r.backend then
            cc.interactions.chat.adapter = r.backend
            cc.interactions.agent.adapter = r.backend
          end
          -- Retarget chat buffers that are already open.
          --
          -- Only within one transport: moving a live chat between an ACP
          -- adapter and an HTTP one tears down an in-flight ACP connection
          -- and throws from a scheduled callback (acp/init.lua indexing a nil
          -- `defaults`), which no pcall here can catch because it fires after
          -- this returns. Cross-transport changes therefore apply to the next
          -- chat, and say so.
          local ok, chat_mod = pcall(require, "codecompanion.interactions.chat")
          if ok and chat_mod.buf_get_chat then
            local target
            if r.backend then
              local resolved, ad = pcall(require("codecompanion.adapters").resolve, r.backend)
              target = resolved and ad or nil
            end
            for _, entry in ipairs(chat_mod.buf_get_chat() or {}) do
              local chat = entry.chat or entry
              if chat and chat.adapter then
                local swapping = target and chat.adapter.name ~= target.name
                if swapping and target.type ~= chat.adapter.type then
                  vim.notify(
                    ("ai: %s is %s, this chat is %s -- applies to the next chat"):format(
                      r.backend,
                      target.type,
                      chat.adapter.type
                    ),
                    vim.log.levels.INFO
                  )
                else
                  if swapping then
                    -- Refused once a chat holds tool calls or reasoning.
                    pcall(function()
                      chat:change_adapter(r.backend)
                    end)
                  end
                  if r.model then
                    pcall(function()
                      chat:change_model({model = r.model})
                    end)
                  end
                end
              end
            end
          end
        end
      end)
    end
  '';
}
