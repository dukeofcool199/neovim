{ ... }:
{
  plugins.cmp = {
    enable = true;

    settings = {
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
        "<CR>" = "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })";
        "<Tab>" = ''
          cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" })
        '';
        "<S-Tab>" = ''
          cmp.mapping(function(fallback)
            local luasnip = require('luasnip')
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" })
        '';
      };

      sources = [
        { name = "nvim_lsp"; }
        { name = "luasnip"; }
      ];
    };
  };

  plugins.cmp-nvim-lsp.enable = true;
  plugins.luasnip.enable = true;
  plugins.cmp_luasnip.enable = true;
}
