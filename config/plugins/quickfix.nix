{ pkgs, ... }: {
  extraPlugins = with pkgs.vimPlugins; [
    quicker-nvim
    nvim-bqf
    fzf-wrapper
  ];

  extraPackages = with pkgs; [
    fzf
  ];

  extraConfigLua = ''
    -- Use ripgrep for :grep and :Cgrep
    vim.o.grepprg = "rg --vimgrep --no-heading --smart-case"
    vim.o.grepformat = "%f:%l:%c:%m,%f:%l:%m"

    -- quicker.nvim: editable quickfix + context expansion + styling
    local quicker_ok, quicker = pcall(require, "quicker")
    if quicker_ok then
      quicker.setup({
        keys = {
          {
            ">",
            function()
              require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
            end,
            desc = "Expand quickfix context",
          },
          {
            "<",
            function()
              require("quicker").collapse()
            end,
            desc = "Collapse quickfix context",
          },
        },
        edit = {
          enabled = true,
          autosave = "unmodified",
        },
        constrain_cursor = true,
        highlight = {
          treesitter = true,
          lsp = true,
          load_buffers = false,
        },
        borders = {
          vert = "┃",
          strong_header = "━",
          strong_cross = "╋",
          strong_end = "┫",
          soft_header = "╌",
          soft_cross = "╂",
          soft_end = "┨",
        },
      })
    end

    -- nvim-bqf: preview, sign filtering, fzf filtering
    local bqf_ok, bqf = pcall(require, "bqf")
    if bqf_ok then
      bqf.setup({
        auto_enable = true,
        auto_resize_height = true,
        preview = {
          auto_preview = true,
          border = "rounded",
          show_title = true,
          show_scroll_bar = true,
          win_height = 15,
          win_vheight = 15,
          delay_syntax = 80,
          should_preview_cb = function(bufnr, qwinid)
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            local fsize = vim.fn.getfsize(bufname)
            if fsize > 500 * 1024 then
              return false
            end
            if bufname:match("^fugitive://") or bufname:match("^jj://") or bufname:match("^diffview://") then
              return false
            end
            return true
          end,
        },
        func_map = {
          open = "<CR>",
          openc = "o",
          drop = "O",
          tab = "t",
          tabb = "T",
          tabc = "<C-t>",
          split = "s",
          vsplit = "v",
          prevhist = "(",
          nexthist = ")",
          ptoggleitem = "p",
          ptoggleauto = "P",
          ptogglemode = "zp",
          stoggleup = "<S-Tab>",
          stoggledown = "<Tab>",
          filter = "zn",
          filterr = "zN",
          fzffilter = "zf",
        },
        filter = {
          fzf = {
            extra_opts = { "--bind", "ctrl-o:toggle-all" },
            action_for = {
              ["ctrl-t"] = "tabedit",
              ["ctrl-v"] = "vsplit",
              ["ctrl-x"] = "split",
            },
          },
        },
      })
    end

    -- quickfix/location-list buffer-local keymaps
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "qf",
      callback = function(args)
        local buf = args.buf
        local winid = vim.fn.win_getid()
        local info = vim.fn.getwininfo(winid)[1] or {}
        local is_loc = info.loclist == 1

        local map = function(keys, action, desc)
          vim.keymap.set("n", keys, action, { buffer = buf, silent = true, noremap = true, desc = desc })
        end

        map("q", is_loc and "<cmd>lclose<cr>" or "<cmd>cclose<cr>", "Close list")
        map("r", function()
          require("quicker").refresh(is_loc and winid or nil)
        end, "Refresh list")

        -- delete current item from the list
        map("dd", function()
          if is_loc then
            local meta = vim.fn.getloclist(0, { idx = 0, id = 0 })
            local list = vim.fn.getloclist(0)
            if meta.idx > 0 and meta.idx <= #list then
              table.remove(list, meta.idx)
              vim.fn.setloclist(0, {}, "r", { items = list, id = meta.id })
            end
          else
            local meta = vim.fn.getqflist({ idx = 0, id = 0 })
            local list = vim.fn.getqflist()
            if meta.idx > 0 and meta.idx <= #list then
              table.remove(list, meta.idx)
              vim.fn.setqflist({}, "r", { items = list, id = meta.id })
            end
          end
        end, "Delete list item")
      end,
    })

    -- Save/load named quickfix and location lists
    local function list_path(scope, name)
      return vim.fn.stdpath("data") .. "/" .. scope .. "/" .. name .. ".json"
    end

    local function list_save(scope, name)
      local is_loc = scope == "l"
      local list = is_loc and vim.fn.getloclist(0) or vim.fn.getqflist()
      local path = list_path(scope, name)
      vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
      local f = io.open(path, "w")
      if f then
        f:write(vim.fn.json_encode(list))
        f:close()
        vim.notify("Saved " .. (is_loc and "location" or "quickfix") .. " list: " .. name)
      else
        vim.notify("Failed to save " .. (is_loc and "location" or "quickfix") .. " list: " .. name, vim.log.levels.ERROR)
      end
    end

    local function list_load(scope, name)
      local is_loc = scope == "l"
      local path = list_path(scope, name)
      local f = io.open(path, "r")
      if not f then
        vim.notify("No saved " .. (is_loc and "location" or "quickfix") .. " list: " .. name, vim.log.levels.ERROR)
        return
      end
      local content = f:read("*a")
      f:close()
      local ok, list = pcall(vim.fn.json_decode, content)
      if not ok or type(list) ~= "table" then
        vim.notify("Failed to decode " .. (is_loc and "location" or "quickfix") .. " list: " .. name, vim.log.levels.ERROR)
        return
      end
      if is_loc then
        vim.fn.setloclist(0, list)
        vim.cmd("lopen")
      else
        vim.fn.setqflist(list)
        vim.cmd("copen")
      end
      vim.notify("Loaded " .. (is_loc and "location" or "quickfix") .. " list: " .. name)
    end

    vim.api.nvim_create_user_command("Csave", function(opts) list_save("c", opts.args) end, { nargs = 1 })
    vim.api.nvim_create_user_command("Cload", function(opts) list_load("c", opts.args) end, { nargs = 1 })
    vim.api.nvim_create_user_command("Lsave", function(opts) list_save("l", opts.args) end, { nargs = 1 })
    vim.api.nvim_create_user_command("Lload", function(opts) list_load("l", opts.args) end, { nargs = 1 })
    vim.api.nvim_create_user_command("Cdelete", function() vim.fn.setqflist({}) end, {})
    vim.api.nvim_create_user_command("Ldelete", function() vim.fn.setloclist(0, {}) end, {})

    -- Guarded :cdo / :cfdo / :ldo / :lfdo
    local function guarded_do(cmd, scope)
      local is_loc = scope == "l"
      local count = is_loc and #vim.fn.getloclist(0) or #vim.fn.getqflist()
      if count == 0 then
        vim.notify((is_loc and "Location" or "Quickfix") .. " list is empty", vim.log.levels.WARN)
        return
      end
      if count > 50 then
        local choice = vim.fn.confirm(
          "Run " .. cmd .. " on " .. count .. " " .. (is_loc and "location" or "quickfix") .. " items?",
          "&Yes\n&No",
          2
        )
        if choice ~= 1 then
          return
        end
      end
      vim.cmd(cmd)
    end

    vim.api.nvim_create_user_command("Cdo", function(opts)
      guarded_do("cdo " .. opts.args, "c")
    end, { nargs = "+" })

    vim.api.nvim_create_user_command("Cfdo", function(opts)
      guarded_do("cfdo " .. opts.args, "c")
    end, { nargs = "+" })

    vim.api.nvim_create_user_command("Ldo", function(opts)
      guarded_do("ldo " .. opts.args, "l")
    end, { nargs = "+" })

    vim.api.nvim_create_user_command("Lfdo", function(opts)
      guarded_do("lfdo " .. opts.args, "l")
    end, { nargs = "+" })

    -- Wrap-around navigation
    local function qf_next(scope)
      local is_loc = scope == "l"
      local getinfo = is_loc and function() return vim.fn.getloclist(0, { idx = 0 }) end or function() return vim.fn.getqflist({ idx = 0 }) end
      local before = getinfo().idx
      local ok = pcall(vim.cmd, is_loc and "lnext" or "cnext")
      if not ok then
        pcall(vim.cmd, is_loc and "lrewind" or "crewind")
        return
      end
      local after = getinfo().idx
      if after <= before then
        pcall(vim.cmd, is_loc and "lrewind" or "crewind")
      end
    end

    local function qf_prev(scope)
      local is_loc = scope == "l"
      local getinfo = is_loc and function() return vim.fn.getloclist(0, { idx = 0 }) end or function() return vim.fn.getqflist({ idx = 0 }) end
      local before = getinfo().idx
      local ok = pcall(vim.cmd, is_loc and "lprev" or "cprev")
      if not ok then
        pcall(vim.cmd, is_loc and "llast" or "clast")
        return
      end
      local after = getinfo().idx
      if after >= before then
        pcall(vim.cmd, is_loc and "llast" or "clast")
      end
    end

    vim.api.nvim_create_user_command("Cnext", function() qf_next("c") end, {})
    vim.api.nvim_create_user_command("Cprev", function() qf_prev("c") end, {})
    vim.api.nvim_create_user_command("Lnext", function() qf_next("l") end, {})
    vim.api.nvim_create_user_command("Lprev", function() qf_prev("l") end, {})

    -- Grep to quickfix
    vim.api.nvim_create_user_command("Cgrep", function(opts)
      vim.cmd("silent grep! " .. opts.args)
      vim.cmd("copen")
    end, { nargs = "+", complete = "file" })

    -- Auto-open quickfix after :grep/:make/:vimgrep/:helpgrep if results exist
    vim.api.nvim_create_autocmd("QuickFixCmdPost", {
      pattern = { "grep", "make", "vimgrep", "helpgrep" },
      callback = function()
        if #vim.fn.getqflist() > 0 then
          vim.cmd("copen")
        end
      end,
    })

    -- Load a jj diff summary into the quickfix list
    vim.api.nvim_create_user_command("JjQf", function(opts)
      local revset = opts.args ~= "" and opts.args or "@"
      local cmd = "jj diff --summary -r " .. vim.fn.shellescape(revset)
      local output = vim.fn.system(cmd)
      if vim.v.shell_error ~= 0 then
        vim.notify("jj diff failed: " .. output, vim.log.levels.ERROR)
        return
      end

      local items = {}
      for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
        local status, path = line:match("^([MADR])%s+(.+)$")
        if status and path then
          if status == "R" then
            local new_path = path:match("^.+%s+→%s+(.+)$")
            if new_path then
              path = vim.trim(new_path)
            end
          end
          table.insert(items, {
            filename = path,
            lnum = 1,
            text = status .. " " .. path,
          })
        end
      end

      vim.fn.setqflist({}, "r", { items = items, title = "jj diff " .. revset })
      if #items > 0 then
        vim.cmd("copen")
      else
        vim.notify("No changed files for revset: " .. revset, vim.log.levels.INFO)
      end
    end, { nargs = "?", complete = "file" })
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>qq";
      action.__raw = ''function() require("quicker").toggle() end'';
      options = { desc = "Toggle quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>ql";
      action.__raw = ''function() require("quicker").toggle({ loclist = true }) end'';
      options = { desc = "Toggle location list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qo";
      action.__raw = ''function() require("quicker").open() end'';
      options = { desc = "Open quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qO";
      action.__raw = ''function() require("quicker").open({ loclist = true }) end'';
      options = { desc = "Open location list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qc";
      action.__raw = ''function() require("quicker").close() end'';
      options = { desc = "Close quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qC";
      action.__raw = ''function() require("quicker").close({ loclist = true }) end'';
      options = { desc = "Close location list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qn";
      action = "<cmd>Cnext<cr>";
      options = { desc = "Next quickfix item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qp";
      action = "<cmd>Cprev<cr>";
      options = { desc = "Previous quickfix item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qN";
      action = "<cmd>Lnext<cr>";
      options = { desc = "Next location item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qP";
      action = "<cmd>Lprev<cr>";
      options = { desc = "Previous location item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "]q";
      action = "<cmd>Cnext<cr>";
      options = { desc = "Next quickfix item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "[q";
      action = "<cmd>Cprev<cr>";
      options = { desc = "Previous quickfix item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "]l";
      action = "<cmd>Lnext<cr>";
      options = { desc = "Next location item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "[l";
      action = "<cmd>Lprev<cr>";
      options = { desc = "Previous location item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qf";
      action.__raw = ''function() vim.diagnostic.setqflist() end'';
      options = { desc = "Diagnostics to quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qF";
      action.__raw = ''function() vim.diagnostic.setloclist() end'';
      options = { desc = "Diagnostics to location list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qg";
      action = "<cmd>Cgrep<space>";
      options = { desc = "Grep to quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qt";
      action = "<cmd>Telescope quickfix<cr>";
      options = { desc = "Telescope quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qT";
      action = "<cmd>Telescope loclist<cr>";
      options = { desc = "Telescope loclist"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qj";
      action = "<cmd>JjQf<cr>";
      options = { desc = "jj diff to quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qs";
      action = "<cmd>Csave<space>";
      options = { desc = "Save quickfix list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qr";
      action = "<cmd>Cload<space>";
      options = { desc = "Restore quickfix list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qS";
      action = "<cmd>Lsave<space>";
      options = { desc = "Save location list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qR";
      action = "<cmd>Lload<space>";
      options = { desc = "Restore location list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qy";
      action = "<cmd>chistory<cr>";
      options = { desc = "Quickfix history"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qd";
      action = "<cmd>Cdelete<cr>";
      options = { desc = "Clear quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qD";
      action = "<cmd>Ldelete<cr>";
      options = { desc = "Clear location list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qx";
      action = "<cmd>Cdo<space>";
      options = { desc = "Run command on each item"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qX";
      action = "<cmd>Cfdo<space>";
      options = { desc = "Run command on each file"; silent = true; };
    }
    {
      mode = "n";
      key = "]Q";
      action = "<cmd>clast<cr>";
      options = { desc = "Last quickfix item"; silent = true; };
    }
    {
      mode = "n";
      key = "[Q";
      action = "<cmd>crewind<cr>";
      options = { desc = "First quickfix item"; silent = true; };
    }
    {
      mode = "n";
      key = "]L";
      action = "<cmd>llast<cr>";
      options = { desc = "Last location item"; silent = true; };
    }
    {
      mode = "n";
      key = "[L";
      action = "<cmd>lrewind<cr>";
      options = { desc = "First location item"; silent = true; };
    }
  ];
}
