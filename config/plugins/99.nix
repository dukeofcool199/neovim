{pkgs, ...}: let
  plugin-99 = pkgs.vimUtils.buildVimPlugin {
    name = "99";
    src = pkgs.fetchFromGitHub {
      owner = "dukeofcool199";
      repo = "99";
      rev = "c17422457027c913c76c75a921fca1e623d2678e";
      sha256 = "0jnbjgcvw72z0xjqngkc941wva9rv7ybqaldxlpp541mdy46jaca";
    };
    patches = [./patches/99-opencode-fix.patch];
    doCheck = false;
  };
in {
  extraPlugins = [plugin-99];

  extraPackages = [pkgs.opencode];

  extraConfigLua = ''
    local _99 = require("99")
    local cwd = vim.uv.cwd()
    local basename = vim.fs.basename(cwd)

    _99.setup({
      provider = _99.Providers.OpenCodeProvider,
      model = "opencode-go/kimi-k2.7-code",
      logger = {
        level = _99.DEBUG,
        path = "/tmp/" .. basename .. ".99.debug",
        print_on_error = true,
      },
      tmp_dir = "./tmp",
      completion = {
        source = "native",
      },
      md_files = {
        "AGENT.md",
      },
    })
  '';

  keymaps = [
    {
      mode = "v";
      key = "<leader>9v";
      action.__raw = ''
        function()
          require("99").visual()
        end
      '';
      options = {
        desc = "99: visual replacement";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9s";
      action.__raw = ''
        function()
          require("99").search()
        end
      '';
      options = {
        desc = "99: search";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9x";
      action.__raw = ''
        function()
          require("99").stop_all_requests()
        end
      '';
      options = {
        desc = "99: stop all requests";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9o";
      action.__raw = ''
        function()
          require("99").open()
        end
      '';
      options = {
        desc = "99: open last interaction";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9l";
      action.__raw = ''
        function()
          require("99").view_logs()
        end
      '';
      options = {
        desc = "99: view logs";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9m";
      action.__raw = ''
        function()
          require("99.extensions.telescope").select_model()
        end
      '';
      options = {
        desc = "99: select model (telescope)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>9p";
      action.__raw = ''
        function()
          require("99.extensions.telescope").select_provider()
        end
      '';
      options = {
        desc = "99: select provider (telescope)";
        silent = true;
        noremap = true;
      };
    }
  ];
}
