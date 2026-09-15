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
    local list_undo = {}

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "qf",
      callback = function(args)
        local buf = args.buf
        local winid = vim.fn.win_getid()
        local info = vim.fn.getwininfo(winid)[1] or {}
        local is_loc = info.loclist == 1

        local map = function(keys, action, desc, modes)
          vim.keymap.set(modes or "n", keys, action, { buffer = buf, silent = true, noremap = true, desc = desc })
        end

        local function get_list(win, what)
          if is_loc then
            return what and vim.fn.getloclist(win, what) or vim.fn.getloclist(win)
          end
          return what and vim.fn.getqflist(what) or vim.fn.getqflist()
        end

        local function set_list(win, items, id, idx)
          local what = { items = items, id = id }
          if idx > 0 then
            what.idx = idx
          end
          if is_loc then
            vim.fn.setloclist(win, {}, "r", what)
          else
            vim.fn.setqflist({}, "r", what)
          end
        end

        -- qf buffer line N is list entry N, so delete by cursor line, not by active idx
        local function delete_range(first, last)
          local win = vim.api.nvim_get_current_win()
          local items = get_list(win)
          if #items == 0 then
            return
          end
          first, last = math.max(first, 1), math.min(last, #items)
          if first > last then
            return
          end

          local id = get_list(win, { id = 0 }).id
          local stack = list_undo[buf]
          if not stack or stack.id ~= id then
            stack = { id = id }
            list_undo[buf] = stack
          end
          table.insert(stack, vim.deepcopy(items))
          if #stack > 32 then
            table.remove(stack, 1)
          end

          for i = last, first, -1 do
            table.remove(items, i)
          end
          set_list(win, items, id, math.min(first, #items))
          pcall(vim.api.nvim_win_set_cursor, win, { math.min(first, math.max(#items, 1)), 0 })
        end

        map("q", is_loc and "<cmd>lclose<cr>" or "<cmd>cclose<cr>", "Close list")
        map("r", function()
          require("quicker").refresh(is_loc and winid or nil)
        end, "Refresh list")

        map("dd", function()
          local line = vim.api.nvim_win_get_cursor(0)[1]
          delete_range(line, line + vim.v.count1 - 1)
        end, "Delete list item")

        map("d", function()
          local first, last = vim.fn.line("v"), vim.fn.line(".")
          if first > last then
            first, last = last, first
          end
          vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
          delete_range(first, last)
        end, "Delete selected list items", "x")

        map("u", function()
          local win = vim.api.nvim_get_current_win()
          local stack = list_undo[buf]
          local id = get_list(win, { id = 0 }).id
          if not stack or stack.id ~= id or #stack == 0 then
            vim.notify("Nothing to undo", vim.log.levels.WARN)
            return
          end
          set_list(win, table.remove(stack), id, 1)
        end, "Undo list delete")
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

    -- Search pattern (@/, as set by * or /) to quickfix
    local function pattern_items(bufnr, pat)
      local items = {}
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      for lnum, line in ipairs(lines) do
        local from = 0
        while from <= #line do
          local m = vim.fn.matchstrpos(line, pat, from)
          local s, e = m[2], m[3]
          if s < 0 then
            break
          end
          table.insert(items, {
            bufnr = bufnr,
            lnum = lnum,
            col = s + 1,
            end_col = e + 1,
            text = line,
            valid = 1,
          })
          from = e > s and e or s + 1
        end
      end
      return items
    end

    local function search_to_qf(all_buffers)
      local pat = vim.fn.getreg("/")
      if pat == "" then
        vim.notify("No search pattern", vim.log.levels.WARN)
        return
      end

      local bufs
      if all_buffers then
        bufs = vim.tbl_filter(function(b)
          return vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted and vim.bo[b].buftype == ""
        end, vim.api.nvim_list_bufs())
      else
        bufs = { vim.api.nvim_get_current_buf() }
      end

      local items = {}
      for _, b in ipairs(bufs) do
        vim.list_extend(items, pattern_items(b, pat))
      end

      if #items == 0 then
        vim.notify("No matches for /" .. pat, vim.log.levels.WARN)
        return
      end

      vim.fn.setqflist({}, " ", { title = "/" .. pat, items = items })
      vim.cmd("copen")
    end

    vim.api.nvim_create_user_command("Csearch", function() search_to_qf(false) end, {})
    vim.api.nvim_create_user_command("Csearchall", function() search_to_qf(true) end, {})

    -- Word/selection to quickfix, project-wide via grepprg
    local function grep_literal(text, whole_word)
      if text == "" then
        return
      end
      local flags = whole_word and "-F -w " or "-F "
      vim.cmd("silent grep! " .. flags .. vim.fn.shellescape(text))
      if #vim.fn.getqflist() == 0 then
        vim.notify("No matches for " .. text, vim.log.levels.WARN)
      end
    end

    local function visual_text()
      local ok, lines = pcall(
        vim.fn.getregion,
        vim.fn.getpos("'<"),
        vim.fn.getpos("'>"),
        { type = vim.fn.visualmode() }
      )
      if not ok or type(lines) ~= "table" then
        return ""
      end
      return lines[1] or ""
    end

    vim.api.nvim_create_user_command("Cword", function(opts)
      grep_literal(opts.args ~= "" and opts.args or vim.fn.expand("<cword>"), opts.args == "")
    end, { nargs = "?" })

    vim.api.nvim_create_user_command("Cselection", function()
      grep_literal(visual_text(), false)
    end, {})

    -- Auto-open quickfix after :grep/:make/:vimgrep/:helpgrep if results exist
    vim.api.nvim_create_autocmd("QuickFixCmdPost", {
      pattern = { "grep", "make", "vimgrep", "helpgrep" },
      callback = function()
        if #vim.fn.getqflist() > 0 then
          vim.cmd("copen")
        end
      end,
    })
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
      action.__raw = ''function() local p = vim.fn.input("Grep to quickfix: ") if p ~= "" then vim.cmd("Cgrep " .. p) end end'';
      options = { desc = "Grep to quickfix"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>q/";
      action = "<cmd>Csearch<cr>";
      options = { desc = "Search pattern to quickfix (buffer)"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>q?";
      action = "<cmd>Csearchall<cr>";
      options = { desc = "Search pattern to quickfix (all buffers)"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>q*";
      action = "<cmd>Cword<cr>";
      options = { desc = "Word under cursor to quickfix (project)"; silent = true; };
    }
    {
      mode = "x";
      key = "<leader>q*";
      action = ":<C-u>Cselection<cr>";
      options = { desc = "Selection to quickfix (project)"; silent = true; };
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
      key = "<leader>qs";
      action.__raw = ''function() local n = vim.fn.input("Save quickfix list: ") if n ~= "" then vim.cmd({ cmd = "Csave", args = { n } }) end end'';
      options = { desc = "Save quickfix list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qr";
      action.__raw = ''function() local n = vim.fn.input("Restore quickfix list: ") if n ~= "" then vim.cmd({ cmd = "Cload", args = { n } }) end end'';
      options = { desc = "Restore quickfix list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qS";
      action.__raw = ''function() local n = vim.fn.input("Save location list: ") if n ~= "" then vim.cmd({ cmd = "Lsave", args = { n } }) end end'';
      options = { desc = "Save location list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qR";
      action.__raw = ''function() local n = vim.fn.input("Restore location list: ") if n ~= "" then vim.cmd({ cmd = "Lload", args = { n } }) end end'';
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
      action.__raw = ''function() local c = vim.fn.input("Cdo: ") if c ~= "" then vim.cmd("Cdo " .. c) end end'';
      options = { desc = "Run command on each item"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qX";
      action.__raw = ''function() local c = vim.fn.input("Cfdo: ") if c ~= "" then vim.cmd("Cfdo " .. c) end end'';
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
