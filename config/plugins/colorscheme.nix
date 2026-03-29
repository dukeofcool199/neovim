{...}: {
  extraConfigLua = ''
    local _colorscheme = {
      config_path = vim.fn.stdpath("data") .. "/colorscheme.json",
      default_scheme = "monokai-pro",
      filetype_overrides = {},
      _original_scheme = nil,
    }

    function _colorscheme.apply(name)
      local ok, err = pcall(vim.cmd, "colorscheme " .. name)
      if not ok then
        vim.notify("Colorscheme '" .. name .. "' not found: " .. err, vim.log.levels.WARN)
        return false
      end
      return true
    end

    function _colorscheme.current()
      return vim.g.colors_name or _colorscheme.default_scheme
    end

    function _colorscheme.save(name)
      local data = vim.json.encode({
        colorscheme = name,
        filetype_overrides = _colorscheme.filetype_overrides,
      })
      local f = io.open(_colorscheme.config_path, "w")
      if f then
        f:write(data)
        f:close()
        vim.notify("Colorscheme saved: " .. name, vim.log.levels.INFO)
      end
    end

    function _colorscheme.load()
      local f = io.open(_colorscheme.config_path, "r")
      if not f then return nil end
      local content = f:read("*a")
      f:close()
      local ok, data = pcall(vim.json.decode, content)
      if ok and data then
        if data.filetype_overrides then
          _colorscheme.filetype_overrides = data.filetype_overrides
        end
        return data.colorscheme
      end
      return nil
    end

    function _colorscheme.set_filetype_override(ft, scheme)
      _colorscheme.filetype_overrides[ft] = scheme
      _colorscheme.save(_colorscheme.current())
      vim.notify("Filetype '" .. ft .. "' -> colorscheme '" .. scheme .. "'", vim.log.levels.INFO)
    end

    function _colorscheme.remove_filetype_override(ft)
      _colorscheme.filetype_overrides[ft] = nil
      _colorscheme.save(_colorscheme.current())
      vim.notify("Removed colorscheme override for '" .. ft .. "'", vim.log.levels.INFO)
    end

    function _colorscheme.telescope_pick()
      local ok, builtin = pcall(require, "telescope.builtin")
      if not ok then
        vim.notify("Telescope not available", vim.log.levels.ERROR)
        return
      end
      builtin.colorscheme({
        enable_preview = true,
        attach_mappings = function(prompt_bufnr, map)
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")
          actions.select_default:replace(function()
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if entry then
              _colorscheme.apply(entry.value)
              _colorscheme._original_scheme = nil
            end
          end)
          return true
        end,
      })
    end

    -- Filetype override autocmd
    vim.api.nvim_create_autocmd({"BufEnter", "FileType"}, {
      group = vim.api.nvim_create_augroup("ColorSchemeFileType", { clear = true }),
      callback = function()
        local ft = vim.bo.filetype
        local override = _colorscheme.filetype_overrides[ft]
        if override then
          if not _colorscheme._original_scheme then
            _colorscheme._original_scheme = _colorscheme.current()
          end
          _colorscheme.apply(override)
        elseif _colorscheme._original_scheme then
          _colorscheme.apply(_colorscheme._original_scheme)
          _colorscheme._original_scheme = nil
        end
      end,
    })

    -- User commands
    vim.api.nvim_create_user_command("ColorScheme", function(opts)
      local name = opts.args
      if name == "" then
        vim.notify("Current: " .. _colorscheme.current(), vim.log.levels.INFO)
        return
      end
      if _colorscheme.apply(name) then
        _colorscheme._original_scheme = nil
      end
    end, {
      nargs = "?",
      complete = "color",
      desc = "Switch colorscheme",
    })

    vim.api.nvim_create_user_command("ColorSchemeSave", function()
      _colorscheme.save(_colorscheme.current())
    end, { desc = "Save current colorscheme" })

    vim.api.nvim_create_user_command("ColorSchemeLoad", function()
      local name = _colorscheme.load()
      if name then
        _colorscheme.apply(name)
        vim.notify("Loaded colorscheme: " .. name, vim.log.levels.INFO)
      else
        vim.notify("No saved colorscheme found", vim.log.levels.WARN)
      end
    end, { desc = "Load saved colorscheme" })

    vim.api.nvim_create_user_command("ColorSchemeFileType", function(opts)
      local args = vim.split(opts.args, "%s+")
      if #args == 0 or args[1] == "" then
        if vim.tbl_isempty(_colorscheme.filetype_overrides) then
          vim.notify("No filetype overrides set", vim.log.levels.INFO)
          return
        end
        local lines = {}
        for ft, scheme in pairs(_colorscheme.filetype_overrides) do
          table.insert(lines, "  " .. ft .. " -> " .. scheme)
        end
        vim.notify("Filetype overrides:\n" .. table.concat(lines, "\n"), vim.log.levels.INFO)
        return
      end
      if #args == 1 then
        _colorscheme.remove_filetype_override(args[1])
        return
      end
      _colorscheme.set_filetype_override(args[1], args[2])
    end, {
      nargs = "*",
      desc = "Set/list/remove filetype colorscheme overrides",
    })

    -- Load saved colorscheme on startup
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("ColorSchemeStartup", { clear = true }),
      callback = function()
        local saved = _colorscheme.load()
        if saved and saved ~= _colorscheme.current() then
          _colorscheme.apply(saved)
        end
      end,
      once = true,
    })
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>tc";
      action.__raw = ''
        function()
          _colorscheme.telescope_pick()
        end
      '';
      options = {
        desc = "Pick Colorscheme";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>tS";
      action = "<cmd>ColorSchemeSave<CR>";
      options = {
        desc = "Save Colorscheme";
        silent = true;
        noremap = true;
      };
    }
  ];
}
