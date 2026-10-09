# Org babel and org-attach for nvim-orgmode, which can tangle but not evaluate and has no
# attach. A headless Emacs per nvim does the real work on a snapshot of the buffer; the
# changed lines come back as a diff, so results land in place without saving, reloading or
# blocking the editor.
{pkgs, ...}: let
  emacs = pkgs.emacs-nox;
  epkgs = pkgs.emacsPackagesFor emacs;

  bootstrap = pkgs.writeText "nvim-org-babel.el" ''
    ;;; nvim-org-babel.el --- org-babel engine for Neovim's orgmode  -*- lexical-binding: t -*-

    (setq auto-save-list-file-prefix nil
          make-backup-files nil
          create-lockfiles nil
          native-comp-jit-compilation nil)

    ;; Some built-in ob-* evaluate through packages Emacs doesn't ship (ob-haskell needs
    ;; inf-haskell from haskell-mode). -Q skips site-start, so put them on load-path here.
    (dolist (pkg '("${epkgs.haskell-mode}"))
      (let ((default-directory (concat pkg "/share/emacs/site-lisp/elpa")))
        (normal-top-level-add-subdirs-to-load-path)))

    ;; Fallback toolchains, appended so a devshell's own ghc earlier on PATH still wins.
    (dolist (dir '("${pkgs.ghc}/bin"))
      (add-to-list 'exec-path dir t)
      (setenv "PATH" (concat (getenv "PATH") path-separator dir)))

    (require 'org)
    (require 'org-attach)
    (setq org-confirm-babel-evaluate nil
          ;; org-roam indexes IDs on the nvim side; Emacs' own ID file would only go stale.
          org-id-track-globally nil)
    (org-babel-do-load-languages
     'org-babel-load-languages
     '((awk . t) (C . t) (calc . t) (clojure . t) (css . t) (ditaa . t) (dot . t)
       (emacs-lisp . t) (eshell . t) (forth . t) (fortran . t) (gnuplot . t) (groovy . t)
       (haskell . t) (java . t) (js . t) (julia . t) (latex . t) (lilypond . t) (lisp . t)
       (lua . t) (makefile . t) (matlab . t) (maxima . t) (ocaml . t) (octave . t) (org . t)
       (perl . t) (plantuml . t) (processing . t) (python . t) (R . t) (ruby . t) (sass . t)
       (scheme . t) (screen . t) (sed . t) (shell . t) (sql . t) (sqlite . t)))

    ;; nvim kills the daemon on exit; this covers nvim dying without running VimLeavePre.
    (let ((parent (string-to-number (getenv "NVIM_ORG_BABEL_PARENT"))))
      (run-with-timer 10 10 (lambda () (unless (process-attributes parent) (kill-emacs)))))

    (require 'url)
    (require 'mm-decode)

    ;; org-attach's own url method names the file with the query string left on and asks
    ;; whether the host is safe, which would hang a daemon; url-copy-file saves error pages.
    (defun nvim-org-babel-download (url)
      "Fetch URL into a fresh temp dir, named after the last part of its path; return the file."
      (let* ((path (car (url-path-and-query (url-generic-parse-url url))))
             (name (decode-coding-string (url-unhex-string (file-name-nondirectory (or path ""))) 'utf-8))
             (buffer (or (url-retrieve-synchronously url t nil 300)
                         (user-error "Could not fetch %s" url)))
             (status (with-current-buffer buffer (bound-and-true-p url-http-response-status))))
        (unwind-protect
            (if (not (and status (<= 200 status 299)))
                (user-error "HTTP %s fetching %s" status url)
              (let ((file (expand-file-name (if (string-empty-p name) "download" name)
                                            (make-temp-file "nvim-org-attach" t)))
                    (handle (with-current-buffer buffer (mm-dissect-buffer t))))
                (mm-save-part-to-file handle file)
                (mm-destroy-parts handle)
                file))
          (kill-buffer buffer))))

    (defun nvim-org-babel (action in out err file line char &optional arg)
      "Run babel ACTION on the org text in IN as though it were FILE, with point at LINE/CHAR.
    ARG is the local file or http(s) URL to bring in for the attach actions; attach-source also
    links a URL it was downloaded from.
    Write the resulting text to OUT and the error output buffer to ERR; return any echo-area error."
      (let ((coding-system-for-read 'utf-8-unix)
            (coding-system-for-write 'utf-8-unix)
            ;; The snapshot buffer visits no file, which org-id refuses when creating an ID.
            (org-id-overriding-file-name file)
            (failure nil))
        (with-temp-buffer
          (insert-file-contents in)
          (org-mode)
          (setq default-directory (file-name-directory file))
          (goto-char (point-min))
          (forward-line (1- line))
          (forward-char (min char (- (line-end-position) (point))))
          (when (get-buffer org-babel-error-buffer-name)
            (kill-buffer org-babel-error-buffer-name))
          (condition-case e
              (pcase action
                ("execute" (unless (org-babel-execute-maybe) (user-error "No code block at point")))
                ("buffer" (org-babel-execute-buffer))
                ("subtree" (org-babel-execute-subtree))
                ("remove" (org-babel-remove-result))
                ("remove-all" (org-babel-remove-result-one-or-many t))
                ((or "attach" "attach-source")
                 ;; org-attach only resolves a relative data/ dir in a file-visiting buffer,
                 ;; and can only tag an entry that has a heading.
                 (let* ((org-attach-id-dir (expand-file-name org-attach-id-dir))
                        (org-attach-auto-tag (unless (org-before-first-heading-p) org-attach-auto-tag))
                        (url (string-match-p "\\`https?://" arg))
                        (source (if url (nvim-org-babel-download arg) arg))
                        (link (concat (org-link-make-string (concat "attachment:" (file-name-nondirectory source)))
                                      (when (and url (equal action "attach-source"))
                                        (concat " (" (org-link-make-string arg "source") ")"))))
                        (here (point-marker))
                        (meta (memq (org-element-type (org-element-at-point))
                                    '(headline keyword property-drawer node-property drawer planning))))
                   (unwind-protect
                       (org-attach-attach source nil (if url 'mv 'cp))
                     (when url
                       (delete-directory (file-name-directory source) t)))
                   (goto-char here)
                   ;; In text the link goes after the cursor, like nvim's `a'; on a heading or
                   ;; its metadata, below that metadata; in the file header, at its end.
                   (cond ((not meta) (unless (eolp) (forward-char)) (insert link))
                         ((org-before-first-heading-p)
                          (goto-char (or (save-excursion (outline-next-heading)) (point-max)))
                          (skip-chars-backward " \t\n")
                          (insert "\n\n" link))
                         (t (org-back-to-heading t) (org-end-of-meta-data t) (insert link "\n"))))))
            (error (setq failure (error-message-string e))))
          (when-let ((buf (get-buffer org-babel-error-buffer-name)))
            (with-current-buffer buf (write-region nil nil err nil 'silent))
            (kill-buffer buf))
          (write-region nil nil out nil 'silent))
        failure))
  '';
in {
  extraConfigLua = ''
    package.preload["org-babel"] = function()
      local M = {}

      local ns = vim.api.nvim_create_namespace("org-babel")
      local sock = vim.fn.stdpath("run") .. "/org-babel-emacs-" .. vim.fn.getpid()
      local daemon, ready, waiting = nil, false, {}
      local error_buf

      local function start()
        os.remove(sock)
        local home = vim.fn.stdpath("cache") .. "/org-babel-emacs"
        vim.fn.mkdir(home, "p")
        local log = {}
        local proc
        proc = vim.system({
          "${emacs}/bin/emacs", "-Q", "--init-directory=" .. home,
          "--load", "${bootstrap}", "--fg-daemon=" .. sock,
        }, {
          env = { NVIM_ORG_BABEL_PARENT = tostring(vim.fn.getpid()) },
          stderr = function(_, data)
            if data and not ready then
              table.insert(log, data)
            end
          end,
        }, function()
          vim.schedule(function()
            if daemon == proc then
              daemon, ready = nil, false
            end
          end)
        end)
        daemon = proc

        -- Emacs creates the socket only after --load has finished, so it doubles as "ready".
        local timer = assert(vim.uv.new_timer())
        local waited = 0
        timer:start(50, 50, vim.schedule_wrap(function()
          waited = waited + 50
          if daemon ~= nil and daemon ~= proc then
            timer:close()
            return
          end
          local up = daemon == proc and vim.uv.fs_stat(sock) ~= nil
          if up or daemon == nil or waited > 30000 then
            timer:close()
            ready = up
            local queued = waiting
            waiting = {}
            if not up then
              if daemon == proc then
                proc:kill("sigterm")
                daemon = nil
              end
              if #queued > 0 then
                vim.notify("org-babel: Emacs did not start\n" .. table.concat(log), vim.log.levels.ERROR)
              end
            end
            for _, fn in ipairs(queued) do
              fn(up)
            end
          end
        end))
      end

      local function with_daemon(fn)
        if ready then
          return fn(true)
        end
        table.insert(waiting, fn)
        if not daemon then
          start()
        end
      end

      local function stop()
        if daemon then
          daemon:kill("sigterm")
        end
        daemon, ready, waiting = nil, false, {}
        os.remove(sock)
      end

      local function elisp_string(s)
        return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
      end

      local function show_errors(lines)
        if not (error_buf and vim.api.nvim_buf_is_valid(error_buf)) then
          error_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_name(error_buf, "Org-Babel Error Output")
          vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = error_buf, nowait = true })
        end
        vim.api.nvim_buf_set_lines(error_buf, 0, -1, false, lines)
        if vim.fn.bufwinid(error_buf) == -1 then
          local win = vim.api.nvim_get_current_win()
          vim.cmd("botright " .. math.min(#lines + 1, 12) .. "split")
          vim.api.nvim_win_set_buf(0, error_buf)
          vim.api.nvim_set_current_win(win)
        end
      end

      -- The user may keep editing while Emacs runs, so Emacs' hunks (against the snapshot) are
      -- shifted past the user's own edits, and nothing is applied if both touched the same lines.
      local function apply(buf, snapshot, result)
        local function text(lines)
          return table.concat(lines, "\n") .. "\n"
        end
        local function span(hunk)
          if hunk[2] == 0 then
            return hunk[1], hunk[1]
          end
          return hunk[1] - 1, hunk[1] - 1 + hunk[2]
        end

        local theirs = vim.diff(text(snapshot), text(result), { result_type = "indices" })
        local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local mine = vim.diff(text(snapshot), text(current), { result_type = "indices" })

        local placed = {}
        for _, hunk in ipairs(theirs) do
          local s, e = span(hunk)
          local shift = 0
          for _, edit in ipairs(mine) do
            local us, ue = span(edit)
            if us <= e and s <= ue then
              return false
            end
            if ue <= s then
              shift = shift + edit[4] - edit[2]
            end
          end
          table.insert(placed, { s + shift, e + shift, vim.list_slice(result, hunk[3], hunk[3] + hunk[4] - 1) })
        end
        -- Results arrive asynchronously; close the undo block on both sides so `u` reverts
        -- exactly one evaluation instead of merging it with whatever the user typed around it.
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("let &undolevels = &undolevels")
          for i = #placed, 1, -1 do
            vim.api.nvim_buf_set_lines(buf, placed[i][1], placed[i][2], false, placed[i][3])
          end
          vim.cmd("let &undolevels = &undolevels")
        end)
        return true
      end

      ---Run an ACTION (execute, buffer, subtree, remove, remove-all, attach ARG) at the cursor.
      function M.run(action, arg)
        local buf = vim.api.nvim_get_current_buf()
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local snapshot = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local line = snapshot[row] or ""
        local char = vim.str_utfindex(line, "utf-32", math.min(col, #line), false)
        local file = vim.api.nvim_buf_get_name(buf)
        if file == "" then
          file = vim.fn.getcwd() .. "/untitled.org"
        end

        local tmp = vim.fn.tempname()
        local input, out, err = tmp .. ".in.org", tmp .. ".out.org", tmp .. ".err"
        vim.fn.writefile(snapshot, input)
        local mark = vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, {
          virt_text = { { "  babel: " .. action .. "…", "Comment" } },
        })

        with_daemon(function(up)
          if not up then
            if vim.api.nvim_buf_is_valid(buf) then
              vim.api.nvim_buf_del_extmark(buf, ns, mark)
            end
            os.remove(input)
            return
          end
          local sexp = ("(nvim-org-babel %s %s %s %s %s %d %d%s)"):format(
            elisp_string(action), elisp_string(input), elisp_string(out), elisp_string(err),
            elisp_string(file), row, char, arg and " " .. elisp_string(arg) or ""
          )
          vim.system({ "${emacs}/bin/emacsclient", "-s", sock, "--eval", sexp }, { text = true },
            vim.schedule_wrap(function(res)
              if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_del_extmark(buf, ns, mark)
              end
              local errors = vim.fn.filereadable(err) == 1 and vim.fn.readfile(err) or {}
              local result = vim.fn.filereadable(out) == 1 and vim.fn.readfile(out) or nil
              for _, path in ipairs({ input, out, err }) do
                os.remove(path)
              end
              if res.code ~= 0 then
                table.insert(errors, 1, vim.trim(res.stderr or ""))
              end
              if #errors > 0 then
                show_errors(errors)
              end
              local failure = vim.trim(res.stdout or "")
              if failure:sub(1, 1) == '"' then
                vim.notify("org-babel: " .. failure:sub(2, -2):gsub("\\(.)", "%1"), vim.log.levels.WARN)
              end
              if result and vim.api.nvim_buf_is_valid(buf) and not apply(buf, snapshot, result) then
                vim.notify("org-babel: you edited where the results go; run it again", vim.log.levels.WARN)
              end
            end)
          )
        end)
      end

      ---Move to the next (dir > 0) or previous src block header, like C-c C-v n / p.
      function M.goto_block(dir)
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        local query = vim.treesitter.query.parse("org", [[(block name: (expr) @name (#any-of? @name "src" "SRC"))]])
        local root = vim.treesitter.get_parser(0, "org"):parse()[1]:root()
        local target
        for _, node in query:iter_captures(root, 0) do
          local start = node:start()
          if (dir > 0 and start > row and (not target or start < target))
            or (dir < 0 and start < row and (not target or start > target)) then
            target = start
          end
        end
        if target then
          vim.api.nvim_win_set_cursor(0, { target + 1, 0 })
        end
      end

      ---Copy FILE or download an http(s) URL (prompted for when nil) into the attachment dir
      ---of the entry at the cursor. With WITH_SOURCE, a downloaded file's URL is linked too.
      function M.attach(file, with_source)
        local function attach(path)
          if not path or path == "" then
            return
          end
          if not path:match("^https?://") then
            -- Emacs runs in the note's directory, not nvim's cwd.
            path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
            if vim.fn.filereadable(path) == 0 then
              vim.notify("org-attach: not a readable file: " .. path, vim.log.levels.ERROR)
              return
            end
          end
          M.run(with_source and "attach-source" or "attach", path)
        end
        if file then
          return attach(file)
        end
        vim.ui.input({ prompt = "Attach file or URL: ", completion = "file" }, attach)
      end

      ---The dir org-attach uses for the entry at the cursor, or nil without a :DIR: or :ID:.
      local function attach_dir()
        local files = require("orgmode").files
        local headline = files:get_closest_headline_or_nil()
        local dir, id
        if headline then
          dir, id = headline:get_property("DIR", true), headline:get_property("ID", true)
        else
          local file = files:get_current_file()
          dir, id = file:get_property("DIR"), file:get_property("ID")
        end
        if not dir and id then
          -- org-attach-id-uuid-folder-format under the default org-attach-id-dir.
          dir = "data/" .. id:sub(1, 2) .. "/" .. id:sub(3)
        end
        if not dir then
          return nil
        end
        if not dir:match("^[/~]") then
          dir = vim.fs.joinpath(vim.fn.expand("%:p:h"), dir)
        end
        return vim.fs.normalize(dir)
      end

      ---Open [[attachment:NAME]] from the dir org-attach would use for the entry at the cursor.
      function M.follow_attachment(link)
        if not vim.startswith(link, "attachment:") then
          return false
        end
        local name = link:sub(#"attachment:" + 1):gsub("::.*$", "")
        local dir = attach_dir()
        if not dir then
          vim.notify("org-attach: no :ID: or :DIR: on this entry", vim.log.levels.WARN)
          return true
        end
        local path = vim.fs.joinpath(dir, name)
        if vim.fn.filereadable(path) == 0 then
          vim.notify("org-attach: missing " .. path, vim.log.levels.WARN)
          return true
        end
        local fd = io.open(path, "rb")
        local head = fd and fd:read(1024) or ""
        if fd then
          fd:close()
        end
        -- image.nvim renders images in a buffer; other binaries go to the desktop opener.
        local ext = (path:match("%.(%w+)$") or ""):lower()
        if vim.tbl_contains({ "png", "jpg", "jpeg", "gif", "webp", "avif" }, ext) or not head:find("\0", 1, true) then
          vim.cmd.edit(vim.fn.fnameescape(path))
        else
          vim.ui.open(path)
        end
        return true
      end

      ---attachment:NAME completions for the files attached to the entry at the cursor.
      function M.complete_attachment(context)
        local dir = attach_dir()
        if not dir then
          return {}
        end
        local items = {}
        for name, type in vim.fs.dir(dir) do
          local item = "attachment:" .. name
          if type == "file" and context.matcher(item, context.base) then
            table.insert(items, item)
          end
        end
        table.sort(items)
        return items
      end

      function M.restart()
        stop()
        with_daemon(function(up)
          if up then
            vim.notify("org-babel: Emacs restarted, sessions cleared")
          end
        end)
      end

      vim.api.nvim_create_autocmd("VimLeavePre", { callback = stop })
      vim.api.nvim_create_user_command("OrgBabelRestart", M.restart, { desc = "Restart the org-babel Emacs" })

      return M
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "org",
      callback = function(ev)
        local function map(lhs, fn, desc)
          vim.keymap.set("n", lhs, fn, { buffer = ev.buf, desc = desc })
        end
        local babel = function(action)
          return function()
            require("org-babel").run(action)
          end
        end
        map("<leader>obe", babel("execute"), "org babel execute")
        map("<leader>obb", babel("buffer"), "org babel execute buffer")
        map("<leader>obs", babel("subtree"), "org babel execute subtree")
        map("<leader>obk", babel("remove"), "org babel remove result")
        map("<leader>obK", babel("remove-all"), "org babel remove all results")
        map("<leader>obn", function() require("org-babel").goto_block(1) end, "org babel next block")
        map("<leader>obp", function() require("org-babel").goto_block(-1) end, "org babel previous block")
        map("<leader>of", function() require("org-babel").attach() end, "org attach file or URL")
        map("<leader>oF", function() require("org-babel").attach(nil, true) end, "org attach, linking the source URL")
        vim.api.nvim_buf_create_user_command(ev.buf, "OrgAttach", function(opts)
          require("org-babel").attach(opts.args ~= "" and opts.args or nil, opts.bang)
        end, {
          nargs = "?",
          bang = true,
          complete = "file",
          desc = "Attach a file or http(s) URL to the entry at the cursor; ! links the URL too",
        })
      end,
    })
  '';

  # Emacs' attachment: link type; orgmode reads hyperlink sources at setup, before
  # extraConfigLua defines the module, so the source only looks it up when called.
  plugins.orgmode.settings.hyperlinks.sources = [
    {
      __raw = ''
        {
          get_name = function() return "attachment" end,
          follow = function(_, link) return require("org-babel").follow_attachment(link) end,
          -- orgmode passes the completion context here, not the link string its docs describe.
          autocomplete = function(_, context) return require("org-babel").complete_attachment(context) end,
        }
      '';
    }
  ];
}
