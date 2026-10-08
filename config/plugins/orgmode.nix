{pkgs, ...}: let
  notes = "~/notes";
in {
  plugins.orgmode = {
    enable = true;
    settings = {
      org_agenda_files = "${notes}/**/*";
      org_default_notes_file = "${notes}/refile.org";
      org_hide_leading_stars = true;
      org_hide_emphasis_markers = true;
      # Replaced by the list-aware <CR> below, which falls back to this action.
      mappings.org.org_return = false;
      org_capture_templates.j = {
        description = "Journal";
        template = "* %<%H:%M> %?";
        target = "${notes}/journal.org";
        datetree = true;
      };
    };
  };

  # ~/notes is its own git repo; without this, entering a note would move the global cwd of
  # every project tab there. The notes tab gets a tab-local cwd instead. Both entries are
  # needed: project-nvim anchors each glob and checks file paths as well as directories.
  plugins.project-nvim.settings.exclude_dirs = [notes "${notes}/*"];

  keymaps = [
    {
      mode = "n";
      key = "<leader>oh";
      action.__raw = ''
        function()
          -- Found by tab variable, not cwd: project-nvim moves the global cwd on BufEnter.
          for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            if vim.t[tab].notes then
              vim.api.nvim_set_current_tabpage(tab)
              return
            end
          end
          local dir = vim.fn.expand("${notes}")
          vim.cmd.tabnew(dir .. "/index.org")
          vim.cmd.tcd(dir)
          vim.t.notes = true
        end
      '';
      options.desc = "Notes tab";
    }
    {
      mode = "n";
      key = "<leader>of";
      action.__raw = ''
        function()
          require("telescope.builtin").find_files({ cwd = vim.fn.expand("${notes}"), prompt_title = "Notes" })
        end
      '';
      options.desc = "Find a note";
    }
    {
      mode = "n";
      key = "<leader>og";
      action.__raw = ''
        function()
          require("telescope.builtin").live_grep({ cwd = vim.fn.expand("${notes}"), prompt_title = "Search notes" })
        end
      '';
      options.desc = "Search notes";
    }
  ];

  plugins.cmp.settings.sources = [{name = "orgmode";}];

  plugins.otter = {
    enable = true;
    # Its LspAttach hook would activate otter in every LSP buffer, not just org.
    autoActivate = false;
    settings.handle_leading_whitespace = true;
  };

  # image.nvim has no org integration; orgmode ships queries/org/images.scm for snacks.
  # snacks would otherwise attach to every language with an images.scm and hijack image
  # files, both of which image.nvim already owns.
  plugins.snacks = {
    enable = true;
    settings.image = {
      enabled = true;
      formats.__empty = null;
      doc.enabled = false;
    };
  };
  extraPackages = [pkgs.imagemagick];

  extraConfigLua = ''
    -- Numbers each ordered list 1, 2, 3..., or onward from an item's [@N] cookie, as Emacs does.
    -- With a row, only the list holding the item that starts there.
    local function renumber_lists(buf, row)
      local root = vim.treesitter.get_parser(buf, "org"):parse()[1]:root()
      for _, list in vim.treesitter.query.parse("org", "(list) @list"):iter_captures(root, buf) do
        local items, wanted = {}, not row
        for node in list:iter_children() do
          if node:type() == "listitem" then
            table.insert(items, node)
            wanted = wanted or node:start() == row
          end
        end
        if wanted then
          local n = 1
          for _, item in ipairs(items) do
            local bullet = item:child(0)
            local text = vim.treesitter.get_node_text(bullet, buf)
            local closer = text:match("^%d+([.)])$")
            if closer then
              local r, from, _, to = bullet:range()
              local after = vim.api.nvim_buf_get_lines(buf, r, r + 1, true)[1]:sub(to + 1)
              n = tonumber(after:match("^%s+%[@(%d+)%]")) or n
              if text ~= n .. closer then
                vim.api.nvim_buf_set_text(buf, r, from, r, to, { n .. closer })
              end
              n = n + 1
            end
          end
        end
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "org",
      callback = function(ev)
        require("otter").activate()
        Snacks.image.doc.attach(ev.buf)

        -- Enter at the end of a list item starts the next item (renumbering a numbered list),
        -- and on an empty item ends the list. Anywhere else it is orgmode's own Enter.
        vim.keymap.set("i", "<CR>", function()
          local row, col = vim.fn.line(".") - 1, vim.fn.col(".") - 1
          local line = vim.api.nvim_get_current_line()
          local item
          if line:sub(col + 1):match("^%s*$") then
            local root = vim.treesitter.get_parser(ev.buf, "org"):parse()[1]:root()
            local query = vim.treesitter.query.parse("org", "(listitem) @item")
            -- Captures come outermost first, so the last match is the innermost item.
            for _, node in query:iter_captures(root, ev.buf, row, row + 1) do
              local _, _, last, last_col = node:range()
              if (last_col == 0 and last - 1 or last) == row then
                item = node
              end
            end
          end
          if not item then
            return require("orgmode").action("org_mappings.org_return")
          end

          local first, indent = item:start()
          local bullet = vim.treesitter.get_node_text(item:child(0), ev.buf)
          local checkbox = item:child(1) and item:child(1):type() == "checkbox"
          local rest = line:sub(indent + #bullet + 1):gsub("^%s*%[.%]", "")
          if first == row and rest:match("^%s*$") then
            vim.api.nvim_buf_set_lines(ev.buf, row, row + 1, true, { (" "):rep(indent) })
            vim.api.nvim_win_set_cursor(0, { row + 1, indent })
            return
          end
          local number = tonumber(bullet:match("^%d+"))
          local new = (" "):rep(indent)
            .. (number and (number + 1) .. bullet:sub(-1) or bullet)
            .. (checkbox and " [ ] " or " ")
          vim.api.nvim_buf_set_lines(ev.buf, row + 1, row + 1, true, { new })
          if number then
            renumber_lists(ev.buf, row + 1)
          end
          vim.api.nvim_win_set_cursor(0, { row + 2, #vim.api.nvim_buf_get_lines(ev.buf, row + 1, row + 2, true)[1] })
        end, { buffer = ev.buf, desc = "org return; continue or end a list" })

        -- Auto-indent starts a new line under the heading or item text, so typed stars would
        -- be a list bullet and a typed bullet a nested item. On the space after them, stars
        -- move to column 0 and a bullet to the column of the item above. A callback, not
        -- <expr>: Nvim evaluates <expr> while peeking ahead, before the bullet is inserted.
        vim.keymap.set("i", "<Space>", function()
          local row, col = vim.fn.line(".") - 1, vim.fn.col(".") - 1
          local before = vim.api.nvim_get_current_line():sub(1, col)
          local indent = before:match("^(%s+)%*+$")
          local target = indent and 0
          indent = indent or before:match("^(%s+)[-+]$") or before:match("^(%s+)%d+[.)]$")

          vim.treesitter.get_parser(ev.buf, "org"):parse()
          local node = vim.treesitter.get_node({ pos = { row, math.max(col - 1, 0) }, ignore_injections = true })
          -- A YAML "- " or C " * " line inside #+begin_src stays where it is.
          while node and node:type() ~= "block" do
            node = node:parent()
          end

          if indent and not node then
            local prev = vim.fn.prevnonblank(row) - 1
            if not target and prev >= 0 then
              -- get_node finds nothing at a bullet's own column; the line's last char works.
              local item = vim.treesitter.get_node({
                pos = { prev, math.max(#vim.fn.getline(prev + 1) - 1, 0) },
                ignore_injections = true,
              })
              while item and item:type() ~= "listitem" do
                item = item:parent()
              end
              target = item and select(2, item:start())
            end
            if target and target < #indent then
              vim.api.nvim_buf_set_text(ev.buf, row, 0, row, #indent, { (" "):rep(target) })
            end
          end
          -- <C-]> fires orgmode's abbreviations (:today: ...), which a mapped space skips.
          vim.api.nvim_feedkeys(vim.keycode("<C-]> "), "in", false)
        end, { buffer = ev.buf, desc = "Space; snap typed heading/bullet indent" })
      end,
    })

    -- conform has no org formatter, and orgmode applies its layout only on gq, = or a TODO
    -- change. This applies it to the whole buffer on save. Only differing lines are written,
    -- so saving a formatted file leaves no undo step. Every edit keeps the line count, so rows
    -- found in the first parse stay valid.
    vim.api.nvim_create_autocmd("BufWritePre", {
      callback = function(ev)
        local buf = ev.buf
        if vim.bo[buf].filetype ~= "org" then
          return
        end
        local config = require("orgmode.config")
        local indentexpr = require("orgmode.org.indent").indentexpr
        local Table = require("orgmode.files.elements.table")
        local parser = vim.treesitter.get_parser(buf, "org")
        local query = vim.treesitter.query.parse(
          "org",
          "(block) @block (listitem) @item (table) @table (headline (tag_list) @tags)"
        )
        local function line(row)
          return vim.api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
        end
        local function shift(row, by)
          local text = line(row)
          if by > 0 and not text:match("^%s*$") then
            vim.api.nvim_buf_set_text(buf, row, 0, row, 0, { (" "):rep(by) })
          elseif by < 0 and #text:match("^ *") > 0 then
            vim.api.nvim_buf_set_text(buf, row, 0, row, math.min(-by, #text:match("^ *")), { "" })
          end
        end

        vim.api.nvim_buf_call(buf, function()
          -- First, so the indent pass realigns item text when "9." becomes "10.".
          renumber_lists(buf)
          local blocks, block_at, item_end, tables = {}, {}, {}, {}
          for id, node in query:iter_captures(parser:parse()[1]:root(), buf) do
            local first, _, last, last_col = node:range()
            if last_col == 0 then
              last = last - 1
            end
            if query.captures[id] == "table" then
              table.insert(tables, first)
            elseif query.captures[id] == "item" then
              item_end[first] = last
            elseif query.captures[id] == "block" then
              blocks[first] = { first = first + 1, last = last - 1 }
              for row = first + 1, last - 1 do
                block_at[row] = blocks[first]
              end
            end
          end

          for row = 0, vim.api.nvim_buf_line_count(buf) - 1 do
            local text = line(row)
            local ws = text:match("^%s*")
            if block_at[row] then
              -- Block bodies move as a unit, keeping the code's own indentation; orgmode's
              -- indentexpr would re-indent them with the block language's indentexpr.
              shift(row, block_at[row].shift)
            elseif ws == text then
              if text ~= "" then
                vim.api.nvim_buf_set_text(buf, row, 0, row, #text, { "" })
              end
            else
              local was = vim.fn.indent(row + 1)
              local want = indentexpr(row + 1, buf)
              if want >= 0 and want ~= was then
                vim.api.nvim_buf_set_text(buf, row, 0, row, #ws, { (" "):rep(want) })
                -- An item's lines move with it, or its nested items stop parsing as nested.
                for r = row + 1, item_end[row] or row do
                  shift(r, want - was)
                end
              end
              local block = blocks[row]
              if block then
                local min
                for r = block.first, block.last do
                  if not line(r):match("^%s*$") then
                    min = math.min(min or math.huge, vim.fn.indent(r + 1))
                  end
                end
                block.shift = min and vim.fn.indent(row + 1) + config.org_edit_src_content_indentation - min or 0
              end
            end
          end

          for _, row in ipairs(tables) do
            parser:parse()
            local tbl = Table.from_current_node({ row + 1, #line(row) })
            if tbl then
              local indent = config:get_indent(vim.fn.indent(row + 1), buf)
              local drawn = vim.tbl_map(function(l)
                return indent .. l
              end, tbl:draw())
              if not vim.deep_equal(drawn, vim.api.nvim_buf_get_lines(buf, row, row + #drawn, true)) then
                tbl:reformat()
              end
            end
          end

          -- Same placement as orgmode's own align_tags, which can't say whether it would change
          -- anything: tags end at -org_tags_column, or start at a positive one.
          for _, node in query:iter_captures(parser:parse()[1]:root(), buf) do
            local row, col = node:start()
            if node:type() == "tag_list" then
              local text = line(row)
              local tags = vim.trim(vim.treesitter.get_node_text(node, buf))
              local title = text:sub(1, col):gsub("%s+$", "")
              local column = config.org_tags_column
              local start = column >= 0 and column or -column - vim.api.nvim_strwidth(tags)
              local want = title .. (" "):rep(math.max(start - vim.api.nvim_strwidth(title), 1)) .. tags
              if text ~= want then
                vim.api.nvim_buf_set_lines(buf, row, row + 1, true, { want })
              end
            end
          end
        end)
      end,
    })
  '';
}
