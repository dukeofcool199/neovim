{ ... }: {
  extraConfigLua = ''
    -- jj-review: Fugitive-style code review for Jujutsu VCS
    package.preload["jj-review"] = function()
      local M = {}

      -- Get the jj repository root
      local function get_repo_root()
        local root = vim.trim(vim.fn.system("jj root 2>/dev/null"))
        if vim.v.shell_error ~= 0 then
          return nil
        end
        return root
      end

      -- Check if a revset resolves to the current working copy
      local function is_working_copy(revset)
        local wc_id = vim.trim(vim.fn.system(
          "jj log --no-graph --color never -T "
          .. vim.fn.shellescape("change_id.short(8)")
          .. " -r @ 2>/dev/null"
        ))
        local target_id = vim.trim(vim.fn.system(
          "jj log --no-graph --color never -T "
          .. vim.fn.shellescape("change_id.short(8)")
          .. " -r " .. vim.fn.shellescape(revset) .. " 2>/dev/null"
        ))
        return wc_id ~= "" and wc_id == target_id
      end

      -- Get file content at a specific revision as a list of lines
      local function get_file_at_rev(rev, filepath)
        local output = vim.fn.system(
          "jj file print --color never -r "
          .. vim.fn.shellescape(rev)
          .. " -- " .. vim.fn.shellescape(filepath)
          .. " 2>/dev/null"
        )
        if vim.v.shell_error ~= 0 then
          return {}
        end
        -- Remove trailing newline that vim.split would turn into an empty last line
        if output:sub(-1) == "\n" then
          output = output:sub(1, -2)
        end
        return vim.split(output, "\n", { plain = true })
      end

      -- Get recent revisions from jj log
      local function get_revisions()
        -- Use a lua raw string so \n passes through literally to jj
        local tmpl = [[change_id.short(8) ++ "|" ++ description.first_line() ++ "\n"]]
        local cmd = "jj log --no-graph --color never -n 20 -T "
          .. vim.fn.shellescape(tmpl) .. " 2>&1"
        local output = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
          vim.notify("jj log failed: " .. output, vim.log.levels.ERROR)
          return {}
        end
        local revisions = {}
        for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
          local id, desc = line:match("^([^|]+)|(.*)$")
          if id then
            id = vim.trim(id)
            desc = vim.trim(desc)
            table.insert(revisions, {
              change_id = id,
              description = desc,
              display = id .. "  " .. (desc ~= "" and desc or "(no description)"),
            })
          end
        end
        return revisions
      end

      -- Get files changed in a revset
      local function get_changed_files(revset)
        local output = vim.fn.system(
          "jj diff --color never -r " .. vim.fn.shellescape(revset) .. " --summary 2>&1"
        )
        if vim.v.shell_error ~= 0 then
          return {}
        end
        local files = {}
        for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
          -- Match M/A/D/R prefix followed by path
          local status, path = line:match("^([MADR])%s+(.+)$")
          if status and path then
            -- For renamed files (R old → new), extract the new path
            if status == "R" then
              local new_path = path:match("^.+%s+→%s+(.+)$")
              if new_path then
                path = vim.trim(new_path)
              end
            end
            table.insert(files, {
              status = status,
              path = path,
              display = status .. " " .. path,
            })
          end
        end
        return files
      end

      -- Show a floating unified diff window (read-only)
      local function show_diff_window(revset, filepath)
        local cmd = "jj diff --color never -r " .. vim.fn.shellescape(revset)
        if filepath then
          cmd = cmd .. " -- " .. vim.fn.shellescape(filepath)
        end
        local output = vim.fn.system(cmd .. " 2>&1")

        local title_str
        if filepath then
          title_str = " " .. filepath .. " [" .. revset .. "] "
        else
          title_str = " jj diff: " .. revset .. " "
        end

        local width = math.floor(vim.o.columns * 0.85)
        local height = math.floor(vim.o.lines * 0.8)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false,
          vim.split(output, "\n", { plain = true }))
        vim.bo[buf].modifiable = false
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].filetype = "diff"

        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = width,
          height = height,
          row = row,
          col = col,
          border = "rounded",
          title = title_str,
          title_pos = "center",
          style = "minimal",
        })

        local function close()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end
        vim.keymap.set("n", "q",     close, { buffer = buf, silent = true, desc = "Close diff" })
        vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, desc = "Close diff" })
      end

      -- Open fugitive-style vimdiff: left = parent, right = rev (or actual file if @)
      -- direction: "vertical" (default, side-by-side) or "horizontal" (stacked)
      local function open_vimdiff(revset, filepath, direction)
        local repo_root = get_repo_root()
        if not repo_root then
          vim.notify("Not in a jj repository", vim.log.levels.ERROR)
          return
        end

        local abs_path = repo_root .. "/" .. filepath
        local ft = vim.filetype.match({ filename = filepath }) or ""
        local at_wc = is_working_copy(revset)
        local is_horiz = direction == "horizontal"
        local split_cmd   = is_horiz and "leftabove split"  or "leftabove vsplit"
        local focus_cmd   = is_horiz and "wincmd j"         or "wincmd l"

        -- Build parent (left) buffer
        local parent_lines = get_file_at_rev(revset .. "-", filepath)
        local left_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(left_buf, 0, -1, false, parent_lines)
        vim.bo[left_buf].modifiable = false
        vim.bo[left_buf].buftype = "nofile"
        vim.bo[left_buf].swapfile = false
        pcall(vim.api.nvim_buf_set_name, left_buf,
          "jj://" .. filepath .. "[" .. revset .. "^]")
        if ft ~= "" then
          pcall(function() vim.bo[left_buf].filetype = ft end)
        end

        -- Build right pane
        local right_is_temp = not at_wc
        if at_wc then
          -- Working copy: open the actual file (editable)
          vim.cmd("edit " .. vim.fn.fnameescape(abs_path))
        else
          -- Historical: read-only temp buffer; press 'e' to jj edit
          local rev_lines = get_file_at_rev(revset, filepath)
          local right_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, rev_lines)
          vim.bo[right_buf].modifiable = false
          vim.bo[right_buf].buftype = "nofile"
          vim.bo[right_buf].swapfile = false
          pcall(vim.api.nvim_buf_set_name, right_buf,
            "jj://" .. filepath .. "[" .. revset .. "]")
          if ft ~= "" then
            pcall(function() vim.bo[right_buf].filetype = ft end)
          end
          vim.api.nvim_win_set_buf(0, right_buf)
        end

        local right_win = vim.api.nvim_get_current_win()
        local right_buf = vim.api.nvim_win_get_buf(right_win)
        vim.cmd("diffthis")

        -- Open parent in a split (direction-aware)
        vim.cmd(split_cmd)
        local left_win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(left_win, left_buf)
        vim.cmd("diffthis")

        -- Return focus to right pane
        vim.cmd(focus_cmd)

        -- Close handler: cleans up both panes
        local function close_diff()
          vim.cmd("diffoff!")
          if vim.api.nvim_win_is_valid(left_win) then
            vim.api.nvim_win_close(left_win, true)
          end
          if vim.api.nvim_buf_is_valid(left_buf) then
            pcall(vim.api.nvim_buf_delete, left_buf, { force = true })
          end
          if right_is_temp and vim.api.nvim_buf_is_valid(right_buf) then
            pcall(vim.api.nvim_buf_delete, right_buf, { force = true })
          end
        end

        local kopts = { silent = true }
        vim.keymap.set("n", "q", close_diff,
          vim.tbl_extend("force", kopts, { buffer = right_buf, desc = "Close jj diff" }))
        vim.keymap.set("n", "q", close_diff,
          vim.tbl_extend("force", kopts, { buffer = left_buf, desc = "Close jj diff" }))

        -- Historical revision: 'e' runs `jj edit <rev>` and reopens as working copy
        if right_is_temp then
          vim.keymap.set("n", "e", function()
            local result = vim.fn.system(
              "jj edit " .. vim.fn.shellescape(revset) .. " 2>&1"
            )
            if vim.v.shell_error ~= 0 then
              vim.notify("jj edit failed: " .. result, vim.log.levels.ERROR)
              return
            end
            vim.notify("Now editing: " .. revset, vim.log.levels.INFO)
            -- Tear down current diff
            vim.cmd("diffoff!")
            if vim.api.nvim_win_is_valid(left_win) then
              vim.api.nvim_win_close(left_win, true)
            end
            if vim.api.nvim_buf_is_valid(left_buf) then
              pcall(vim.api.nvim_buf_delete, left_buf, { force = true })
            end
            if vim.api.nvim_buf_is_valid(right_buf) then
              pcall(vim.api.nvim_buf_delete, right_buf, { force = true })
            end
            -- Reopen as working copy diff (preserve split direction)
            open_vimdiff("@", filepath, direction)
          end, vim.tbl_extend("force", kopts, {
            buffer = right_buf, desc = "jj edit this revision"
          }))
        end
      end

      -- Layer 2: Telescope file picker for a revset
      local function open_file_picker(revset)
        local files = get_changed_files(revset)
        if #files == 0 then
          vim.notify("No changes in revset: " .. revset, vim.log.levels.INFO)
          return
        end

        local ok, pickers = pcall(require, "telescope.pickers")
        if not ok then
          vim.notify("Telescope not available", vim.log.levels.ERROR)
          return
        end
        local finders    = require("telescope.finders")
        local conf       = require("telescope.config").values
        local actions    = require("telescope.actions")
        local ast        = require("telescope.actions.state")
        local previewers = require("telescope.previewers")

        pickers.new({}, {
          prompt_title = "Files in: " .. revset,
          finder = finders.new_table({
            results = files,
            entry_maker = function(entry)
              return {
                value   = entry,
                display = entry.display,
                ordinal = entry.path,
                path    = entry.path,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          previewer = previewers.new_buffer_previewer({
            title = "File Diff",
            define_preview = function(self, entry)
              local diff = vim.fn.system(
                "jj diff --color never -r " .. vim.fn.shellescape(revset)
                .. " -- " .. vim.fn.shellescape(entry.path) .. " 2>&1"
              )
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false,
                vim.split(diff, "\n", { plain = true }))
              vim.bo[self.state.bufnr].filetype = "diff"
            end,
          }),
          attach_mappings = function(prompt_bufnr, map)
            -- <Enter> / <C-v>: vertical vimdiff (default)
            actions.select_default:replace(function()
              local entry = ast.get_selected_entry()
              actions.close(prompt_bufnr)
              if entry then
                open_vimdiff(revset, entry.path, "vertical")
              end
            end)
            -- <C-x>: horizontal vimdiff (stacked, like Telescope's horizontal split)
            map("n", "<C-x>", function()
              local entry = ast.get_selected_entry()
              actions.close(prompt_bufnr)
              if entry then
                open_vimdiff(revset, entry.path, "horizontal")
              end
            end)
            map("i", "<C-x>", function()
              local entry = ast.get_selected_entry()
              actions.close(prompt_bufnr)
              if entry then
                open_vimdiff(revset, entry.path, "horizontal")
              end
            end)
            -- d: floating diff for this file only
            map("n", "d", function()
              local entry = ast.get_selected_entry()
              if entry then
                show_diff_window(revset, entry.path)
              end
            end)
            -- D: floating diff for the full revset
            map("n", "D", function()
              show_diff_window(revset, nil)
            end)
            return true
          end,
        }):find()
      end

      -- Layer 1: Telescope revision picker
      function M.review()
        local revisions = get_revisions()
        if #revisions == 0 then
          vim.notify("No jj revisions found", vim.log.levels.ERROR)
          return
        end

        local ok, pickers = pcall(require, "telescope.pickers")
        if not ok then
          vim.notify("Telescope not available", vim.log.levels.ERROR)
          return
        end
        local finders    = require("telescope.finders")
        local conf       = require("telescope.config").values
        local actions    = require("telescope.actions")
        local ast        = require("telescope.actions.state")
        local previewers = require("telescope.previewers")

        pickers.new({}, {
          prompt_title = "jj Review",
          finder = finders.new_table({
            results = revisions,
            entry_maker = function(entry)
              return {
                value   = entry,
                display = entry.display,
                ordinal = entry.display,
              }
            end,
          }),
          sorter = conf.generic_sorter({}),
          previewer = previewers.new_buffer_previewer({
            title = "Changed Files",
            define_preview = function(self, entry)
              local summary = vim.fn.system(
                "jj diff --color never -r "
                .. vim.fn.shellescape(entry.value.change_id)
                .. " --summary 2>&1"
              )
              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false,
                vim.split(summary, "\n", { plain = true }))
            end,
          }),
          attach_mappings = function(prompt_bufnr, map)
            -- <Enter>: open file picker for selected revision
            actions.select_default:replace(function()
              local entry = ast.get_selected_entry()
              actions.close(prompt_bufnr)
              if entry then
                open_file_picker(entry.value.change_id)
              end
            end)
            -- d: show full revision diff in floating window
            map("n", "d", function()
              local entry = ast.get_selected_entry()
              if entry then
                show_diff_window(entry.value.change_id, nil)
              end
            end)
            return true
          end,
        }):find()
      end

      -- Prompt for from/to revsets and open a range diff file picker
      function M.review_range_prompt()
        vim.ui.input({ prompt = "From revset: ", default = "@-" }, function(from)
          if not from or from == "" then return end
          vim.ui.input({ prompt = "To revset: ", default = "@" }, function(to)
            if not to or to == "" then return end
            open_file_picker(from .. ".." .. to)
          end)
        end)
      end

      return M
    end
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>jr";
      action.__raw = ''
        function()
          require("jj-review").review()
        end
      '';
      options = {
        desc = "Review (jj)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>jR";
      action.__raw = ''
        function()
          require("jj-review").review_range_prompt()
        end
      '';
      options = {
        desc = "Review Range (jj)";
        silent = true;
        noremap = true;
      };
    }
  ];
}
