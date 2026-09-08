# jj changes as quickfix items, at file or hunk granularity.
#
# A producer for the quickfix list, not part of it: everything in ./quickfix.nix
# (bqf preview, quicker editing, ]q/[q nav, Cdo) applies for free because this
# only ever calls setqflist.
{pkgs, ...}: {
  extraPackages = with pkgs; [
    jujutsu
  ];

  extraConfigLua = ''
    local function jj_qf_set(items, title)
      vim.schedule(function()
        vim.fn.setqflist({}, "r", { items = items, title = title })
        if #items > 0 then
          vim.cmd("copen")
        else
          vim.notify("No changes for " .. title, vim.log.levels.INFO)
        end
      end)
    end

    local function jj_qf_run(args, cb)
      vim.system(vim.list_extend({ "jj" }, args), { text = true }, function(out)
        if out.code ~= 0 then
          return vim.schedule(function()
            vim.notify("jj diff failed: " .. vim.trim(out.stderr or ""), vim.log.levels.ERROR)
          end)
        end
        cb(out.stdout or "")
      end)
    end

    local function jj_qf_files(revset)
      jj_qf_run({ "diff", "--summary", "-r", revset }, function(output)
        local items = {}
        for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
          local status, path = line:match("^([MADR])%s+(.+)$")
          if status and path then
            -- jj compacts renames git-style: "{old => new}", "dir/{old => new}/file"
            local resolved = path:gsub("{.- => (.-)}", "%1"):gsub("//+", "/")
            table.insert(items, { filename = resolved, lnum = 1, text = status .. " " .. path })
          end
        end
        jj_qf_set(items, "jj diff " .. revset)
      end)
    end

    local function jj_qf_hunks(revset)
      jj_qf_run({ "diff", "--git", "-r", revset }, function(output)
        local items = {}
        local file, hunk

        local function flush_hunk()
          if hunk and file then
            file.saw_hunk = true
            table.insert(items, {
              filename = file.path,
              lnum = math.max(hunk.lnum, 1),
              text = string.format("+%d -%d | %s", hunk.added, hunk.removed,
                hunk.add_preview or hunk.del_preview or ""),
            })
          end
          hunk = nil
        end

        local function flush_file()
          flush_hunk()
          -- renames and mode changes carry no hunks; without this they vanish
          if file and file.path and not file.saw_hunk then
            table.insert(items, { filename = file.path, lnum = 1, text = file.note or "no content change" })
          end
          file = nil
        end

        for _, line in ipairs(vim.split(output, "\n", { plain = true })) do
          local new_start = line:match("^@@ %-%S+ %+(%d+)")
          local a, b = line:match("^diff %-%-git a/(.-) b/(.+)$")
          if a then
            flush_file()
            file = { path = b, old_path = a }
          elseif not file then -- preamble
          elseif line:match("^rename to ") then
            file.note = "renamed from " .. file.old_path
          elseif line:match("^new file mode ") then
            file.note = "new file"
          elseif line:match("^deleted file mode ") then
            file.note = "deleted"
          elseif line:match("^old mode ") then
            file.note = "mode change"
          elseif line:match("^%-%-%- ") then
            file.old_path = line:match("^%-%-%- a/(.+)$") or file.old_path
          elseif line:match("^%+%+%+ ") then
            file.path = line:match("^%+%+%+ b/(.+)$") or file.old_path
          elseif new_start then
            flush_hunk()
            hunk = { lnum = tonumber(new_start), cursor = tonumber(new_start), added = 0, removed = 0 }
          elseif hunk then
            local marker = line:sub(1, 1)
            if marker == "+" then
              hunk.added = hunk.added + 1
              if not hunk.marker then
                hunk.lnum, hunk.marker = hunk.cursor, "+"
              end
              hunk.add_preview = hunk.add_preview or ("+ " .. vim.trim(line:sub(2)))
              hunk.cursor = hunk.cursor + 1
            elseif marker == "-" then
              hunk.removed = hunk.removed + 1
              if not hunk.marker then
                hunk.lnum, hunk.marker = hunk.cursor, "-"
              end
              hunk.del_preview = hunk.del_preview or ("- " .. vim.trim(line:sub(2)))
            elseif marker == " " or line == "" then
              hunk.cursor = hunk.cursor + 1
            end
          end
        end
        flush_file()

        jj_qf_set(items, "jj hunks " .. revset)
      end)
    end

    vim.api.nvim_create_user_command("JjQf", function(opts)
      local revset = opts.args ~= "" and opts.args or "@"
      if opts.bang then
        jj_qf_hunks(revset)
      else
        jj_qf_files(revset)
      end
    end, { nargs = "?", bang = true })
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>qJ";
      action = "<cmd>JjQf<cr>";
      options = {
        desc = "jj diff to quickfix (files)";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>qj";
      action = "<cmd>JjQf!<cr>";
      options = {
        desc = "jj diff to quickfix (hunks)";
        silent = true;
      };
    }
  ];
}
