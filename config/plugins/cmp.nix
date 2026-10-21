{...}: {
  plugins.cmp = {
    enable = true;

    settings = {
      # Manual until <leader>ta; <C-Space> opens the menu either way.
      completion.autocomplete = false;

      # Minuet round-trips an LLM; cmp's 500ms default drops the results.
      performance.fetching_timeout = 2000;

      snippet = {
        expand = ''
          function(args)
            require('luasnip').lsp_expand(args.body)
          end
        '';
      };

      mapping = {
        "<C-j>" = "cmp.mapping.scroll_docs(4)";
        "<C-k>" = "cmp.mapping.scroll_docs(-4)";
        "<C-Space>" = "cmp.mapping.complete()";
        "<Up>" = "cmp.mapping.select_prev_item()";
        "<Down>" = "cmp.mapping.select_next_item()";
        "<CR>" = "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })";
        # Inside a snippet, <Tab> walks the arguments even with the menu open;
        # pick menu items there with <Up>/<Down>.
        "<Tab>" = ''
          cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            elseif cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expandable() then
              luasnip.expand()
            else
              fallback()
            end
          end, { "i", "s" })
        '';
        "<S-Tab>" = ''
          cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            elseif cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" })
        '';
      };

      sources = [
        {name = "nvim_lsp";}
        {name = "luasnip";}
      ];
    };
  };

  plugins.cmp-nvim-lsp.enable = true;
  plugins.cmp_luasnip.enable = true;

  # Without these a snippet you walked away from stays live, and <Tab>
  # elsewhere jumps back into it.
  plugins.luasnip = {
    enable = true;
    settings = {
      region_check_events = "InsertEnter";
      delete_check_events = "TextChanged,InsertLeave";
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>ta";
      action.__raw = ''
        function()
          local cmp = require("cmp")
          local on = not cmp.get_config().completion.autocomplete
          cmp.setup({ completion = { autocomplete = on and { cmp.TriggerEvent.TextChanged } or false } })
          vim.notify("Autocomplete " .. (on and "on" or "off"), vim.log.levels.INFO)
        end
      '';
      options = {
        desc = "Toggle Autocomplete";
        silent = true;
      };
    }
  ];
}
