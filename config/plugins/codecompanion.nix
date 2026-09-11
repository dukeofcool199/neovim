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
            ollama.env.url.__raw = "function() return '${url "inline"}' end";
          };

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
                  url = "${url "fim-remote"}",
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
                    default = "${(role "fim-remote").model}",
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
          adapter = "${(role "chat").acp}";
        };
        chat = {
          adapter = "${(role "chat").acp}";
        };
        # Inline needs an HTTP adapter; ACP cannot serve it. Local ollama by
        # default — the previous `copilot` had no credential on this machine.
        inline = {
          adapter = "${(role "inline").adapter}";
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
        if name == "inline" then
          if r.adapter then
            cc.interactions.inline.adapter = r.adapter
          end
          if r.model and cc.adapters.http.extend and cc.adapters.http.extend[r.adapter] then
            cc.adapters.http.extend[r.adapter].schema =
              vim.tbl_deep_extend("force", cc.adapters.http.extend[r.adapter].schema or {}, {
                model = {default = r.model},
              })
          end
        elseif name == "chat" then
          if r.adapter then
            cc.interactions.chat.adapter = r.adapter
            cc.interactions.agent.adapter = r.adapter
          end
          -- Retarget any chat buffer that is already open.
          local ok, chat_mod = pcall(require, "codecompanion.interactions.chat")
          if ok and chat_mod.buf_get_chat and r.model then
            for _, entry in ipairs(chat_mod.buf_get_chat() or {}) do
              local chat = entry.chat or entry
              pcall(function()
                chat:change_model({model = r.model})
              end)
            end
          end
        end
      end)
    end
  '';
}
