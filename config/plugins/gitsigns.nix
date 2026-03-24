{ ... }:
{
  plugins.gitsigns = {
    enable = true;

    settings = {
      signs = {
        add.text = "+";
        change.text = "~";
        delete.text = "-";
        topdelete.text = "-";
        changedelete.text = "~";
        untracked.text = "┆";
      };
      signcolumn = true;
      numhl = false;
      linehl = false;
      word_diff = false;
      current_line_blame = true;
      attach_to_untracked = true;
      update_debounce = 10;

    };
  };
}
