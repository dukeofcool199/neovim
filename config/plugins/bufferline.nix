{ ... }:
{
  plugins.bufferline = {
    enable = true;

    settings = {
      options = {
        mode = "buffers";
        show_close_icon = false;
        show_buffer_close_icons = false;
        persist_buffer_sort = true;
        diagnostics = "nvim_lsp";
        always_show_bufferline = true;
        separator_style = "slant";
        offsets = [
          {
            filetype = "NvimTree";
            text = "NvimTree";
            highlight = "Directory";
            text_align = "left";
          }
        ];
      };
    };
  };

  # Buffer pick keymap
  keymaps = [
    {
      mode = "n";
      key = "gb";
      action = "<cmd>BufferLinePick<CR>";
      options = {
        desc = "Go to buffer";
        silent = true;
        noremap = true;
      };
    }
  ];
}
