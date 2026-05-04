{...}: {
  plugins.haskell-tools = {
    enable = true;

    settings = {
      tools = {
        repl = {
          handler = "toggleterm";
          auto_focus = true;
        };
        codeLens = {
          autoRefresh = true;
        };
      };
      hls = {
        settings = {
          haskell = {
            formattingProvider = "ormolu";
            checkProject = true;
          };
        };
      };
    };
  };

  extraConfigLua = ''
    -- Auto-refresh and display code lenses
    vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
      pattern = { "*.hs", "*.lhs" },
      callback = function()
        pcall(vim.lsp.codelens.refresh)
      end,
    })

    -- Haskell-tools keymaps (buffer-local)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "haskell", "lhaskell", "cabal" },
      callback = function(args)
        local ht_ok, ht = pcall(require, "haskell-tools")
        if not ht_ok then return end

        -- Patch root_dir once: for files outside any Haskell project (library
        -- files in the Nix store, files in a monorepo without Haskell markers),
        -- reuse the root of an already-running project HLS so vim.lsp.start
        -- deduplicates and attaches the same client instead of starting a new
        -- broken one at CWD. Fall back to git/jj root as a last resort.
        if not ht._root_dir_patched then
          ht._root_dir_patched = true
          local orig_root_dir = ht.project.root_dir
          ht.project.root_dir = function(file)
            local root = orig_root_dir(file)
            if root then return root end
            local clients = vim.lsp.get_clients({ name = 'haskell-tools.nvim' })
            if #clients > 0 and clients[1].config.root_dir then
              return clients[1].config.root_dir
            end
            return vim.fs.root(file, { '.git', '.jj' })
          end
        end

        local bufnr = args.buf
        local opts = function(desc)
          return { buffer = bufnr, silent = true, noremap = true, desc = desc }
        end

        -- After gd, HLS may not have attached to the new buffer yet; wait for it
        vim.keymap.set("n", "gh", function()
          if #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
            vim.lsp.buf.hover()
          else
            vim.api.nvim_create_autocmd("LspAttach", {
              buffer = 0,
              once = true,
              callback = function() vim.lsp.buf.hover() end,
            })
          end
        end, opts("Hover (LSP)"))

        -- Hoogle
        vim.keymap.set("n", "<leader>hs", ht.hoogle.hoogle_signature, opts("Hoogle Signature"))

        -- Hole-driven development: search Hoogle, then <C-r> to fill the hole
        vim.keymap.set("n", "<leader>hf", ht.hoogle.hoogle_signature, opts("Fill Hole (Hoogle)"))

        -- REPL
        vim.keymap.set("n", "<leader>hr", function()
          ht.repl.toggle(vim.api.nvim_buf_get_name(0))
        end, opts("REPL (file)"))
        vim.keymap.set("n", "<leader>hq", ht.repl.quit, opts("REPL Quit"))

        -- Code lenses
        vim.keymap.set("n", "<leader>he", vim.lsp.codelens.run, opts("Eval Code Lens"))

        -- HLS restart
        vim.keymap.set("n", "<leader>hR", ht.lsp.restart, opts("Restart HLS"))
      end,
    })
  '';
}
