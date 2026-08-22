{pkgs, ...}: let
  opencodeVersion = "1.18.21";

  opencode = let
    platform = pkgs.stdenv.hostPlatform.system;
    sources = {
      x86_64-linux = {
        pname = "opencode-linux-x64";
        sha256 = "0mr9q4zywqwx0bnm67zysyqwkpbnbp0d4hjf16q004bgw96zzncj";
      };
      aarch64-linux = {
        pname = "opencode-linux-arm64";
        sha256 = "05kqr755ggd1nzlxdmya1vnx67lxcfwqa7p8sc7d7w0kqcbsgyvc";
      };
      x86_64-darwin = {
        pname = "opencode-darwin-x64";
        sha256 = "0dsva0xcnlrk49irxh9arc74d7ag3hm9wyvq3nkp0740r6g63wgl";
      };
      aarch64-darwin = {
        pname = "opencode-darwin-arm64";
        sha256 = "1plqs4w86c56fny3bh5r72lkb3y5gj9qb3c1h2zawnivsadpk603";
      };
    };
    source =
      sources.${platform}
      or (throw "99: opencode is not available for ${platform}");
  in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "opencode";
      version = opencodeVersion;

      src = pkgs.fetchurl {
        url = "https://registry.npmjs.org/${source.pname}/-/${source.pname}-${opencodeVersion}.tgz";
        inherit (source) sha256;
      };

      sourceRoot = ".";

      nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.autoPatchelfHook];

      buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.glibc];

      installPhase = ''
        mkdir -p $out/bin
        install -m755 package/bin/opencode $out/bin/opencode
      '';

      dontStrip = true;

      meta = {
        description = "OpenCode AI coding agent CLI";
        homepage = "https://opencode.ai";
      };
    };

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

  extraPackages = [opencode];

  extraConfigLua = ''
    local _99 = require("99")
    local cwd = vim.uv.cwd()
    local basename = vim.fs.basename(cwd)

    _99.setup({
      provider = _99.Providers.OpenCodeProvider,
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
  ];
}
