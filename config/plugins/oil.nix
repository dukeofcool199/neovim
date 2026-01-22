{ ... }: {
  plugins.oil = {
    enable = true;

    settings = {
      default_file_explorer = true;
      columns = [ "icon" ];
      buf_options = {
        buflisted = false;
        bufhidden = "hide";
      };
      win_options = {
        wrap = false;
        signcolumn = "no";
        cursorcolumn = false;
        foldcolumn = "0";
        spell = false;
        list = false;
        conceallevel = 3;
        concealcursor = "nvic";
      };
      delete_to_trash = false;
      skip_confirm_for_simple_edits = false;
      prompt_save_on_select_new_entry = true;
      cleanup_delay_ms = 2000;
      lsp_file_methods = {
        enabled = true;
        timeout_ms = 1000;
        autosave_changes = false;
      };
      constrain_cursor = "editable";
      watch_for_changes = false;
      keymaps = {
        "g?" = {
          __unkeyed-1 = "actions.show_help";
          mode = "n";
        };
        "<CR>" = "actions.select";
        "<C-s>" = {
          __unkeyed-1 = "actions.select";
          opts.vertical = true;
        };
        "<C-h>" = {
          __unkeyed-1 = "actions.select";
          opts.horizontal = true;
        };
        "<C-t>" = {
          __unkeyed-1 = "actions.select";
          opts.tab = true;
        };
        "<C-->" = "actions.preview";
        "<C-c>" = {
          __unkeyed-1 = "actions.close";
          mode = "n";
        };
        "<C-l>" = "actions.refresh";
        "-" = {
          __unkeyed-1 = "actions.parent";
          mode = "n";
        };
        "_" = {
          __unkeyed-1 = "actions.open_cwd";
          mode = "n";
        };
        "<C-`>" = {
          __unkeyed-1 = "actions.cd";
          mode = "n";
        };
        "~" = {
          __unkeyed-1 = "actions.cd";
          opts.scope = "tab";
          mode = "n";
        };
        "gs" = {
          __unkeyed-1 = "actions.change_sort";
          mode = "n";
        };
        "gx" = "actions.open_external";
        "g." = {
          __unkeyed-1 = "actions.toggle_hidden";
          mode = "n";
        };
        "g\\" = {
          __unkeyed-1 = "actions.toggle_trash";
          mode = "n";
        };
      };
      use_default_keymaps = false;
      view_options = {
        show_hidden = true;
        natural_order = "fast";
        case_insensitive = false;
        sort = [
          {
            __unkeyed-1 = "type";
            __unkeyed-2 = "asc";
          }
          {
            __unkeyed-1 = "name";
            __unkeyed-2 = "asc";
          }
        ];
      };
      float = {
        padding = 10;
        max_width = 200;
        max_height = 200;
        border = "rounded";
        win_options.winblend = 0;
        close_on_select = true;
        preview_split = "right";
      };
      preview_win = {
        update_on_cursor_moved = true;
        preview_method = "fast_scratch";
      };
      confirmation = {
        max_width = 0.9;
        min_width = [ 40 0.4 ];
        max_height = 0.9;
        min_height = [ 5 0.1 ];
        border = "rounded";
        win_options.winblend = 0;
      };
      progress = {
        max_width = 0.9;
        min_width = [ 40 0.4 ];
        max_height = [ 10 0.9 ];
        min_height = [ 5 0.1 ];
        border = "rounded";
        minimized_border = "none";
        win_options.winblend = 0;
      };
      ssh.border = "rounded";
      keymaps_help.border = "rounded";
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "-";
      action = "<cmd>Oil<cr>";
      options = {
        desc = "Open Oil";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<C-n>";
      action = "<cmd>Oil<cr>";
      options = {
        desc = "Open Oil";
        silent = true;
      };
    }
  ];
}
