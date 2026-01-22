{ ... }:
{
  plugins.toggleterm = {
    enable = true;

    settings = {
      direction = "float";
      close_on_exit = true;
      auto_scroll = true;
      shade_terminals = false;
      float_opts = {
        border = "curved";
        winblend = 3;
      };
    };
  };

  # Custom toggleterm setup with floating terminal
  extraConfigLua = ''
    local Terminal = require("toggleterm.terminal").Terminal

    local is_floating_terminal_mapped = false

    local term = Terminal:new {
      cmd = vim.o.shell,
      direction = "float",
      close_on_exit = true,
      auto_scroll = true,
      shade_terminals = false,
      hidden = true,
      on_open = function(t)
        if not is_floating_terminal_mapped then
          vim.api.nvim_buf_set_keymap(t.bufnr, "t", [[<C-\>]], "", {
            noremap = true,
            callback = function()
              t:toggle()
            end,
          })

          is_floating_terminal_mapped = true
        end

        vim.api.nvim_command("startinsert")
      end
    }

    local function handle_buffer_enter(event)
      local filetype = vim.api.nvim_buf_get_option(event.buf, "filetype")

      if filetype ~= "pager" and filetype ~= "man" then
        vim.api.nvim_buf_set_keymap(event.buf, "n", [[<C-\>]], "", {
          noremap = true,
          callback = function()
            term:toggle()
          end,
        })
      else
        vim.api.nvim_command("norm gg")

        vim.api.nvim_buf_set_keymap(event.buf, "n", "q", "<cmd>q!<cr>", {
          noremap = true,
        })
      end
    end

    vim.api.nvim_create_autocmd(
      { "FileType" },
      {
        pattern = "*",
        callback = handle_buffer_enter,
      }
    )
  '';
}
