# GitHub PR review comments as quickfix items.
#
# A producer for the quickfix list, not part of it: everything in ./quickfix.nix
# (bqf preview, quicker editing, ]q/[q nav, Cdo) applies for free because this
# only ever calls setqflist.
{pkgs, ...}: {
  extraPackages = with pkgs; [
    gh
    jujutsu
  ];

  extraConfigLua = ''
    local function gh_qf_fail(msg)
      vim.schedule(function() vim.notify(msg, vim.log.levels.ERROR) end)
    end

    local function gh_qf_sh(cmd, cb)
      vim.system(cmd, { text = true }, function(out)
        local stdout = vim.trim(out.stdout or "")
        if out.code ~= 0 or stdout == "" or stdout == "null" then
          return cb(nil, vim.trim(out.stderr or ""))
        end
        cb(stdout)
      end)
    end

    local function gh_qf_load(number, origin)
      local endpoint = "repos/{owner}/{repo}/pulls/" .. number .. "/comments"
      gh_qf_sh({ "gh", "api", "--paginate", endpoint }, function(stdout, err)
        if not stdout then
          return gh_qf_fail("gh api failed for PR #" .. number .. ": " .. (err or "no output"))
        end

        -- luanil: JSON null decodes to vim.NIL, which is truthy in Lua
        local ok, comments = pcall(vim.json.decode, stdout, { luanil = { object = true, array = true } })
        if not ok or type(comments) ~= "table" then
          return gh_qf_fail("Could not decode gh response for PR #" .. number)
        end

        local items = {}
        for _, c in ipairs(comments) do
          if c.path then
            -- outdated comments carry line = nil; original_line indexes the old
            -- diff, so it may not line up with the working tree
            local stale = c.line == nil and " [outdated]" or ""
            local body = vim.trim((c.body or ""):gsub("%s+", " "))
            table.insert(items, {
              filename = c.path,
              lnum = c.line or c.original_line or 1,
              text = (c.user and c.user.login or "?") .. stale .. ": " .. body,
            })
          end
        end

        local title = "PR #" .. number .. " comments"
        if origin then
          title = title .. " (" .. origin .. ")"
        end

        vim.schedule(function()
          vim.fn.setqflist({}, "r", { items = items, title = title })
          if #items > 0 then
            vim.cmd("copen")
          else
            vim.notify("No review comments on PR #" .. number, vim.log.levels.INFO)
          end
        end)
      end)
    end

    local function gh_qf_pr_for_head(bookmark, state, cb)
      gh_qf_sh({ "gh", "pr", "list", "--head", bookmark, "--state", state,
                 "--limit", "1", "--json", "number", "-q", ".[0].number" }, cb)
    end

    -- first bookmark with a PR wins; a commit often carries both a feature
    -- bookmark and master, and alphabetical order would pick the wrong one
    local function gh_qf_scan(bookmarks, state, i, cb)
      local bookmark = bookmarks[i]
      if not bookmark then
        return cb(nil)
      end
      gh_qf_pr_for_head(bookmark, state, function(number)
        if number then
          return cb(number, bookmark)
        end
        gh_qf_scan(bookmarks, state, i + 1, cb)
      end)
    end

    -- jj leaves git HEAD permanently detached, so `gh pr view` can never resolve
    -- a branch in a jj repo. Resolve via bookmarks in @'s ancestry and match them
    -- against PR head refs; fall back to the git branch elsewhere.
    local function gh_qf_detect(cb)
      gh_qf_sh({ "jj", "log", "--no-graph", "--ignore-working-copy",
                 "-r", "latest(::@ & bookmarks())",
                 "-T", 'local_bookmarks.map(|b| b.name()).join("\n")' }, function(names)
        local bookmarks = {}
        for _, name in ipairs(names and vim.split(names, "\n") or {}) do
          if name ~= "" then
            table.insert(bookmarks, name)
          end
        end

        if #bookmarks == 0 then
          return gh_qf_sh({ "gh", "pr", "view", "--json", "number", "-q", ".number" }, function(number)
            cb(number, number and "git branch", "the current branch")
          end)
        end

        local tried = "bookmark " .. table.concat(bookmarks, ", ")
        gh_qf_scan(bookmarks, "open", 1, function(number, bookmark)
          if number then
            return cb(number, "bookmark " .. bookmark, tried)
          end
          gh_qf_scan(bookmarks, "all", 1, function(closed, closed_bookmark)
            cb(closed, closed and ("closed PR on bookmark " .. closed_bookmark), tried)
          end)
        end)
      end)
    end

    vim.api.nvim_create_user_command("GhQf", function(opts)
      if opts.args ~= "" then
        return gh_qf_load(opts.args)
      end
      gh_qf_detect(function(number, origin, tried)
        if not number then
          return gh_qf_fail("No PR found for " .. tried .. " -- pass a number: :GhQf 123")
        end
        gh_qf_load(number, origin)
      end)
    end, { nargs = "?" })
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>qh";
      action = "<cmd>GhQf<cr>";
      options = {
        desc = "PR review comments to quickfix";
        silent = true;
      };
    }
  ];
}
