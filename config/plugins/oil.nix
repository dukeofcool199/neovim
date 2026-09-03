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
        is_always_hidden.__raw = ''
          function(name, bufnr)
            local ok, filter = pcall(require, "oil-jj-filter")
            return ok and filter.hidden(name, bufnr) or false
          end
        '';
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

  # oil-jj-filter: open oil at the repo root showing only files changed in @
  # (or @- when @ is empty). <leader>- / g- open the filtered view; - / <C-n> clear it.
  extraConfigLua = ''
    package.preload["oil-jj-filter"] = function()
      local M = { active = false, files = {} }

      local function rerender()
        local ok, view = pcall(require, "oil.view")
        if ok and view.rerender_all_oil_buffers then
          view.rerender_all_oil_buffers({ refetch = false })
        end
      end

      function M.hidden(name, bufnr)
        if not M.active then
          return false
        end
        local dir = require("oil").get_current_dir(bufnr)
        if not dir then
          return false
        end
        return not M.files[(dir .. name):gsub("/$", "")]
      end

      function M.open()
        local root = vim.trim(vim.fn.system("jj root 2>/dev/null"))
        if vim.v.shell_error ~= 0 then
          return vim.notify("Not in a jj repository", vim.log.levels.ERROR)
        end
        local files, count = { [root] = true }, 0
        for _, rev in ipairs({ "@", "@-" }) do
          local out = vim.fn.system(
            "jj diff --summary --no-pager --color never -r " .. rev .. " 2>/dev/null"
          )
          for _, line in ipairs(vim.split(out, "\n", { plain = true })) do
            local path = line:match("^[MADRC]%s+(.+)$")
            if path then
              -- renames print as "R path/{old => new}/rest"
              path = path:gsub("{.- => (.-)}", "%1"):gsub("//+", "/")
              files[root .. "/" .. path] = true
              count = count + 1
              local dir = path:match("^(.*)/[^/]+$")
              while dir do
                files[root .. "/" .. dir] = true
                dir = dir:match("^(.*)/[^/]+$")
              end
            end
          end
          if count > 0 then
            vim.notify(("Oil: %d file(s) changed in %s"):format(count, rev))
            break
          end
        end
        if count == 0 then
          return vim.notify("No changes in @ or @-", vim.log.levels.INFO)
        end
        M.files, M.active = files, true
        rerender()
        require("oil").open(root)
      end

      function M.clear()
        if M.active then
          M.active = false
          rerender()
        end
      end

      return M
    end
  '';

  keymaps = [
    {
      mode = "n";
      key = "-";
      action.__raw = ''
        function()
          require("oil-jj-filter").clear()
          require("oil").open()
        end
      '';
      options = {
        desc = "Open Oil";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<C-n>";
      action.__raw = ''
        function()
          require("oil-jj-filter").clear()
          require("oil").open()
        end
      '';
      options = {
        desc = "Open Oil";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>-";
      action.__raw = ''
        function()
          require("oil-jj-filter").open()
        end
      '';
      options = {
        desc = "Open Oil (jj changed files)";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "g-";
      action.__raw = ''
        function()
          require("oil-jj-filter").open()
        end
      '';
      options = {
        desc = "Open Oil (jj changed files)";
        silent = true;
      };
    }
  ];
}
