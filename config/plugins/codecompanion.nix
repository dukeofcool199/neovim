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
      interactions = {
        agent = {
          adapter = "opencode";
        };
        chat = {
          adapter = "opencode";
        };
        # NOTE: opencode is an ACP (Agent Client Protocol) adapter.
        # CodeCompanion's inline interaction requires an HTTP adapter.
        # Using copilot as the fallback for inline edits.
        inline = {
          adapter = "copilot";
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
