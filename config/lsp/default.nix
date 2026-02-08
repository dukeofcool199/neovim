{...}: {
  plugins.lsp = {
    enable = true;

    keymaps = {
      diagnostic = {
        "[d" = "goto_next";
        "]d" = "goto_prev";
      };

      lspBuf = {
        "gd" = "definition";
        "gD" = "declaration";
        "gh" = "hover";
        "gi" = "implementation";
        "gr" = "references";
        "<C-k>" = "signature_help";
        "<leader>wa" = "add_workspace_folder";
        "<leader>wr" = "remove_workspace_folder";
        "<leader>ca" = "code_action";
        "<leader>cf" = "format";
        "<leader>cr" = "rename";
      };
    };

    servers = {
      # Go
      gopls = {
        enable = true;
      };

      # Rust
      rust_analyzer = {
        enable = true;
        installCargo = false;
        installRustc = false;
        settings = {
          cargo.allFeatures = true;
          procMacro.enable = true;
        };
      };

      # Python
      pyright = {
        enable = true;
      };

      # Templ
      templ = {
        enable = true;
      };

      # OCaml
      ocamllsp = {
        enable = true;
      };

      # Gleam
      gleam = {
        enable = true;
      };

      # Odin
      ols = {
        enable = true;
      };

      # Dart
      dartls = {
        enable = true;
      };

      # Zig
      zls = {
        enable = true;
      };

      # Nix
      nixd = {
        enable = true;
        settings = {
          formatting.command = ["alejandra"];
        };
      };

      # OpenSCAD
      openscad_lsp = {
        enable = true;
      };

      # SQL
      sqls = {
        enable = true;
        onAttach.function = ''
          client.server_capabilities.documentFormattingProvider = false
        '';
      };

      # TypeScript - use default package
      ts_ls = {
        enable = true;
        filetypes = ["typescript" "html" "htmldjango" "javascript" "javascriptreact" "typescriptreact" "vue"];
        onAttach.function = ''
          client.server_capabilities.documentFormattingProvider = false
        '';
      };

      # Vue - use default package
      vue_ls = {
        enable = true;
        onAttach.function = ''
          client.server_capabilities.documentFormattingProvider = false
        '';
      };

      # Svelte - use default package
      svelte = {
        enable = true;
        rootMarkers = ["svelte.config.js"];
        filetypes = ["svelte"];
      };

      # JSON - use default package
      jsonls = {
        enable = true;
      };

      # HTML - use default package
      html = {
        enable = true;
        filetypes = ["html" "htmldjango" "templ" "markdown"];
        onAttach.function = ''
          local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
          if filetype == "markdown" then
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end
        '';
      };

      # CSS - use default package
      cssls = {
        enable = true;
      };

      # Docker - use default package
      dockerls = {
        enable = true;
      };

      # Tailwind - use default package
      tailwindcss = {
        enable = true;
        filetypes = ["templ" "astro" "javascript" "typescript" "react" "html" "typescriptreact" "vue" "svelte" "haskell"];
        extraOptions = {
          init_options = {
            userLanguages = {
              templ = "html";
            };
          };
        };
      };

      # Markdown
      marksman = {
        enable = true;
        filetypes = ["markdown"];
      };

      # Emmet - use default package
      emmet_language_server = {
        enable = true;
        filetypes = ["css" "vue" "eruby" "templ" "html" "htmldjango" "markdown" "javascript" "javascriptreact" "less" "sass" "scss" "pug" "typescriptreact"];
      };

      # Haskell
      hls = {
        enable = true;
        packageFallback = true;
        installGhc = true;
        filetypes = ["haskell" "lhaskell" "cabal"];
      };

      # Lua
      lua_ls = {
        enable = true;
        settings = {
          Lua = {
            telemetry.enable = false;
            format.enable = true;
            workspace.library.__raw = "vim.api.nvim_get_runtime_file('', true)";
          };
        };
      };

      # Astro - use default package
      astro = {
        enable = true;
      };
    };
  };

  # lazydev for neovim lua development (replacement for neodev)
  plugins.lazydev = {
    enable = true;
  };

  # LSP extras
  extraConfigLua = ''
    -- nvim-navic integration with LSP
    local navic_ok, navic = pcall(require, "nvim-navic")

    -- Custom on_attach for additional LSP features
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        local bufnr = args.buf

        if navic_ok and client.server_capabilities.documentSymbolProvider then
          navic.attach(client, bufnr)
        end

        -- Enable completion triggered by <c-x><c-o>
        vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
      end,
    })

    -- Publish diagnostics configuration
    vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
      underline = true,
      update_in_insert = false,
      virtual_text = true,
      virtual_lines = { prefix = "🧨" },
      severity_sort = true,
    })

    -- Configure diagnostic icons
    local signs = { Error = "✘", Warn = "⚠", Hint = "󰌵", Info = "ℹ" }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    -- Astro TypeScript enable
    vim.g.astro_typescript = "enable"
  '';

  # Format on save is handled by conform-nvim in plugins/conform.nix
}
