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
      };
      opts = {
        log_level = "TRACE";
        send_code = true;
        use_default_actions = true;
        use_default_prompts = true;
      };
      strategies = {
        agent = {
          adapter = "ollama";
        };
        chat = {
          adapter = "ollama";
        };
        inline = {
          adapter = "ollama";
        };
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>ca";
      action = "<cmd>CodeCompanionChat<cr>";
      options = {desc = "Start chat";};
    }
    {
      mode = "n";
      key = "<leader>ce";
      action = "<cmd>CodeCompanion<cr>";
      options = {desc = "Edit code";};
    }
    {
      mode = "v";
      key = "<leader>ca";
      action = "<cmd>CodeCompanionChat<cr>";
      options = {desc = "Start chat with selection";};
    }
    {
      mode = "v";
      key = "<leader>ce";
      action = "<cmd>CodeCompanion<cr>";
      options = {desc = "Generate code with selection";};
    }
  ];
}
