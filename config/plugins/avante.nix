{pkgs, ...}: let
  avante = pkgs.vimPlugins.avante-nvim.overrideAttrs (oldAttrs: {
    version = "unstable-2026-03-11";
    src = pkgs.fetchFromGitHub {
      owner = "yetone";
      repo = "avante.nvim";
      rev = "9a7793461549939f1d52b2b309a1aa44680170c8";
      sha256 = "sha256-EEkAoufj29P46RIUrRNG0xJL9Wu4X7LZCS1fer4/nZQ=";
    };
  });
in {
  extraPlugins = with pkgs.vimPlugins; [
    avante
    nui-nvim
    plenary-nvim
  ];

  extraConfigLua = ''
    local avante_ok, avante = pcall(require, "avante")
    if avante_ok then
      require("avante").setup({
        mode = "agentic",
        provider = "opencode",
        behaviour = {
          auto_suggestions = false,
          auto_apply_diff_after_generation = false,
          enable_token_counting = true,
        },
        windows = {
          position = "right",
          width = 30,
        },
        selector = {
          provider = "dressing",
        },
        input = {
          provider = "dressing",
        },
        acp_providers = {
          ["opencode"] = {
            command = "opencode",
            args = { "acp" },
          },
        },
        mappings = {
          suggestion = {
            accept = "<C-l>",
            next = "<C-j>",
            prev = "<C-k>",
            dismiss = "<C-e>",
          },
        },
      })
    end
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>aa";
      action = "<cmd>AvanteAsk<CR>";
      options = {
        desc = "Avante Ask";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>at";
      action = "<cmd>AvanteToggle<CR>";
      options = {
        desc = "Avante Toggle";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ar";
      action = "<cmd>AvanteRefresh<CR>";
      options = {
        desc = "Avante Refresh";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "v";
      key = "<leader>ae";
      action = "<cmd>AvanteEdit<CR>";
      options = {
        desc = "Avante Edit";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>an";
      action = "<cmd>AvanteChatNew<CR>";
      options = {
        desc = "Avante New Chat";
        silent = true;
        noremap = true;
      };
    }
  ];
}
