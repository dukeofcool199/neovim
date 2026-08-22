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
        local map = function(keys, action, desc)
          vim.keymap.set("n", keys, action, { buffer = buf, silent = true, noremap = true, desc = desc })
        end

        local winid = vim.fn.win_getid()
        local info = vim.fn.getwininfo(winid)[1] or {}
        local is_loc = info.loclist == 1

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

    -- Save/load named quickfix lists
    local function qf_path(name)
      return vim.fn.stdpath("data") .. "/qf/" .. name .. ".json"
    end

    local function qf_save(name)
      local list = vim.fn.getqflist()
      local path = qf_path(name)
      vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
      local f = io.open(path, "w")
      if f then
        f:write(vim.fn.json_encode(list))
        f:close()
        vim.notify("Saved quickfix list: " .. name)
      else
        vim.notify("Failed to save quickfix list: " .. name, vim.log.levels.ERROR)
      end
    end

    local function qf_load(name)
      local path = qf_path(name)
      local f = io.open(path, "r")
      if not f then
        vim.notify("No saved quickfix list: " .. name, vim.log.levels.ERROR)
        return
      end
      local content = f:read("*a")
      f:close()
      local ok, list = pcall(vim.fn.json_decode, content)
      if not ok or type(list) ~= "table" then
        vim.notify("Failed to decode quickfix list: " .. name, vim.log.levels.ERROR)
        return
      end
      vim.fn.setqflist(list)
      vim.cmd("copen")
      vim.notify("Loaded quickfix list: " .. name)
    end

    vim.api.nvim_create_user_command("Csave", function(opts) qf_save(opts.args) end, { nargs = 1 })
    vim.api.nvim_create_user_command("Cload", function(opts) qf_load(opts.args) end, { nargs = 1 })
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

    -- Grep to quickfix
    vim.api.nvim_create_user_command("Cgrep", function(opts)
      vim.cmd("silent grep! " .. opts.args)
      vim.cmd("copen")
    end, { nargs = "+", complete = "file" })
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
      action = "<cmd>cnext<cr>";
      options = { desc = "Next quickfix item"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qp";
      action = "<cmd>cprev<cr>";
      options = { desc = "Previous quickfix item"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qN";
      action = "<cmd>lnext<cr>";
      options = { desc = "Next location item"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>qP";
      action = "<cmd>lprev<cr>";
      options = { desc = "Previous location item"; silent = true; };
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
