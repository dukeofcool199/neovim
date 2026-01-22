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

      on_attach = ''
        function(bufnr)
          local gitsigns = require('gitsigns')

          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation
          map('n', ']c', function()
            if vim.wo.diff then return ']c' end
            vim.schedule(function() gitsigns.next_hunk() end)
            return '<Ignore>'
          end, { expr = true })

          map('n', '[c', function()
            if vim.wo.diff then return '[c' end
            vim.schedule(function() gitsigns.prev_hunk() end)
            return '<Ignore>'
          end, { expr = true })

          -- Actions
          map('n', '<leader>hs', '<cmd>Gitsigns stage_hunk<cr>', { desc = 'Stage Hunk' })
          map('n', '<leader>hr', '<cmd>Gitsigns reset_hunk<cr>', { desc = 'Reset Hunk' })
          map('n', '<leader>hS', '<cmd>Gitsigns stage_buffer<cr>', { desc = 'Stage Buffer' })
          map('n', '<leader>hu', '<cmd>Gitsigns undo_stage_hunk<cr>', { desc = 'Undo Stage Hunk' })
          map('n', '<leader>hR', '<cmd>Gitsigns reset_buffer<cr>', { desc = 'Reset Buffer' })
          map('n', '<leader>hp', '<cmd>Gitsigns preview_hunk<cr>', { desc = 'Preview Hunk' })
          map('n', '<leader>hb', function() gitsigns.blame_line { full = true } end, { desc = 'Blame Line' })
          map('n', '<leader>hd', '<cmd>Gitsigns diffthis<cr>', { desc = 'Diff' })
          map('n', '<leader>hD', function() gitsigns.diffthis('~') end, { desc = 'Diff (~)' })
          map('n', '<leader>tb', '<cmd>Gitsigns toggle_current_line_blame<cr>', { desc = 'Toggle Current Line Blame' })
          map('n', '<leader>td', '<cmd>Gitsigns toggle_deleted<cr>', { desc = 'Toggle Deleted' })
        end
      '';
    };
  };
}
