{pkgs, ...}: {
  plugins.codecompanion = {
    enable = true;

    settings = {
      adapters = {
        http = {
          ollama = {
            __raw = ''
              function()
                return require('codecompanion.adapters').extend('ollama', {
                    env = {
                        url = "http://127.0.0.1:11434",
                    },
                    schema = {
                        model = {
                            -- default = 'qwen2.5-coder:7b',
                            default = 'qwen3-coder:30b',
                            -- default = "llama3.1:8b-instruct-q8_0",
                        },
                        num_ctx = {
                            default = 32768,
                        },
                    },
                })
              end
            '';
          };
        };
        acp = {
          opencode = {
            __raw = ''
              function()
                return require('codecompanion.adapters').extend('opencode', {
                    defaults = {
                        timeout = 20000,
                        session_config_options = {
                            model = "openai/gpt-4o",
                        },
                    },
                })
              end
            '';
          };
        };
      };
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
      strategies = {
        agent = {
          adapter = "opencode";
        };
        chat = {
          adapter = "opencode";
        };
        inline = {
          adapter = "ollama";
        };
      };
    };
  };

  keymaps = [
    {
      mode = ["n" "v"];
      key = "<leader>cc";
      action = "<cmd>CodeCompanionChat<cr>";
      options = {desc = "Chat (default adapter)";};
    }
    {
      mode = ["n" "v"];
      key = "<leader>co";
      action = "<cmd>CodeCompanionChat opencode<cr>";
      options = {desc = "Chat (opencode/OpenAI)";};
    }
    {
      mode = ["n" "v"];
      key = "<leader>cl";
      action = "<cmd>CodeCompanionChat ollama<cr>";
      options = {desc = "Chat (ollama/local)";};
    }
    {
      mode = ["n" "v"];
      key = "<leader>ce";
      action = ":CodeCompanion ";
      options = {desc = "Inline edit";};
    }
  ];
}
