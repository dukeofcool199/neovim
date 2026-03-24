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

        local bufnr = args.buf
        local opts = function(desc)
          return { buffer = bufnr, silent = true, noremap = true, desc = desc }
        end

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
