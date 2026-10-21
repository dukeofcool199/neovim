# lsp_signature.nvim — the call's signature in a float while you fill in its
# arguments, with the current parameter highlighted. Independent of cmp, so it
# shows even while autocomplete is manual.
{...}: {
  plugins.lsp-signature = {
    enable = true;
    settings = {
      hint_enable = false;
      floating_window_above_cur_line = true;
      handler_opts.border = "rounded";
    };
  };
}
