{pkgs, ...}: {
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
      strategies = {
        agent = {
          adapter = "opencode";
        };
        chat = {
          adapter = "opencode";
        };
        inline = {
          adapter = "opencode";
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
      key = "<leader>ce";
      action = ":CodeCompanion ";
      options = {desc = "Inline edit";};
    }
  ];
}
