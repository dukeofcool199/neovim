# Progress indication for AI requests.
#
# codecompanion's inline edits replace code in place with no feedback while
# the model thinks, which reads as a hang on a local model. This shows a
# spinner as virtual text on the line being edited, plus a statusline hint.
#
# The request events carry only {id, adapter} -- nothing identifying which
# interaction fired them -- so inline is told apart from chat by the buffer:
# a codecompanion chat buffer renders its own progress, anything else is an
# inline edit in your code.
{...}: {
  extraConfigLua = ''
    package.preload["ai.progress"] = function()
      local M = {}
      local ns = vim.api.nvim_create_namespace("ai_progress")
      local FRAMES = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
      local INTERVAL = 80
      -- Matches the adapter request timeout, so a lost Finished event cannot
      -- strand a spinner on screen forever.
      local MAX_MS = 120000

      local jobs = {}
      local n = 0

      local function clear(job)
        if job.timer then
          job.timer:stop()
          if not job.timer:is_closing() then
            job.timer:close()
          end
          job.timer = nil
        end
        if job.buf and vim.api.nvim_buf_is_valid(job.buf) then
          vim.api.nvim_buf_clear_namespace(job.buf, ns, 0, -1)
        end
      end

      local function draw(job)
        if not (job.buf and vim.api.nvim_buf_is_valid(job.buf)) then
          return
        end
        local line = math.min(job.line, vim.api.nvim_buf_line_count(job.buf) - 1)
        vim.api.nvim_buf_clear_namespace(job.buf, ns, 0, -1)
        pcall(vim.api.nvim_buf_set_extmark, job.buf, ns, line, 0, {
          virt_text = {{" " .. FRAMES[job.frame] .. " " .. job.label, "Comment"}},
          virt_text_pos = "eol",
          hl_mode = "combine",
        })
      end

      --- Begin indicating progress for request `id`.
      --- Anchors to the current buffer and cursor line unless that buffer is
      --- a chat, which draws its own.
      function M.start(id, label, role)
        if jobs[id] then
          return
        end
        local buf = vim.api.nvim_get_current_buf()
        local inline = vim.bo[buf].filetype ~= "codecompanion"
        local job = {
          role = role,
          buf = inline and buf or nil,
          line = inline and (vim.api.nvim_win_get_cursor(0)[1] - 1) or 0,
          label = label or "thinking",
          frame = 1,
          started = vim.uv.now(),
        }
        jobs[id] = job
        n = n + 1

        if job.buf then
          draw(job)
          job.timer = vim.uv.new_timer()
          job.timer:start(
            INTERVAL,
            INTERVAL,
            vim.schedule_wrap(function()
              if not jobs[id] then
                return
              end
              if vim.uv.now() - job.started > MAX_MS then
                M.stop(id)
                return
              end
              job.frame = (job.frame % #FRAMES) + 1
              draw(job)
            end)
          )
        end
        M.redraw()
      end

      --- Mark a role busy without any virtual text. For high-frequency work
      --- like per-keystroke completion, where a spinner in the buffer would
      --- be noise.
      function M.mark(id, role)
        if jobs[id] then
          return
        end
        jobs[id] = {role = role, started = vim.uv.now()}
        n = n + 1
        M.redraw()
      end

      function M.stop(id)
        local job = jobs[id]
        if not job then
          return
        end
        clear(job)
        jobs[id] = nil
        n = math.max(0, n - 1)
        M.redraw()
      end

      function M.stop_all()
        for id in pairs(jobs) do
          M.stop(id)
        end
      end

      function M.active()
        return n > 0
      end

      --- Is a particular role in flight right now?
      function M.running(role)
        for _, job in pairs(jobs) do
          if job.role == role then
            return true
          end
        end
        return false
      end

      --- The animation frame, shared so every segment spins in step.
      function M.frame()
        return FRAMES[(math.floor(vim.uv.now() / INTERVAL) % #FRAMES) + 1]
      end

      --- Statusline fragment: a spinner while any request is in flight.
      function M.status()
        if n == 0 then
          return ""
        end
        local frame = FRAMES[(math.floor(vim.uv.now() / INTERVAL) % #FRAMES) + 1]
        return frame .. " "
      end

      function M.redraw()
        pcall(function()
          require("lualine").refresh()
        end)
      end

      return M
    end

    -- codecompanion -> ai.progress. RequestStarted/Finished are the only
    -- events that bracket the call; CodeCompanionInlineStarted fires after the
    -- response lands, so it is useless as a start signal.
    do
      local group = vim.api.nvim_create_augroup("AiProgress", {clear = true})

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeCompanionRequestStarted",
        callback = function(ev)
          local data = ev.data or {}
          local adapter = data.adapter or {}
          -- The payload says nothing about which interaction fired, so the
          -- buffer decides: a chat buffer is `ask`, anything else is an
          -- inline edit in your own code.
          local role = vim.bo[vim.api.nvim_get_current_buf()].filetype == "codecompanion" and "ask" or "edit"
          require("ai.progress").start(data.id or "?", adapter.formatted_name or adapter.name or "thinking", role)
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeCompanionRequestFinished",
        callback = function(ev)
          require("ai.progress").stop((ev.data or {}).id or "?")
        end,
      })

      -- minuet duet (next-edit prediction) -> ai.progress. Duet has its own
      -- event namespace, separate from minuet's completion events, which are
      -- deliberately left alone: completion fires on every keystroke and a
      -- spinner there would only flicker.
      --
      -- StartedPre is the start signal; it fires before the job is spawned.
      -- The payload carries n_requests, so finishes are counted rather than
      -- assumed to be one. minuet returns early without firing Finished when
      -- a job fails to spawn outright, which is what the timeout in
      -- ai.progress is there to catch.
      local duet_expected, duet_done = 0, 0
      local DUET = "minuet-duet"

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "MinuetDuetRequestStartedPre",
        callback = function(ev)
          local data = ev.data or {}
          duet_expected = data.n_requests or 1
          duet_done = 0
          require("ai.progress").start(DUET, "next edit", "next-edit")
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "MinuetDuetRequestFinished",
        callback = function()
          duet_done = duet_done + 1
          if duet_done >= duet_expected then
            require("ai.progress").stop(DUET)
          end
        end,
      })

      -- minuet completion, folded in from minuet's own lualine component.
      -- No virtual text: this fires on every keystroke and would only
      -- flicker. It marks the completion segment as busy and nothing more.
      local comp_expected, comp_done = 0, 0
      local COMP = "minuet-completion"

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "MinuetRequestStartedPre",
        callback = function(ev)
          comp_expected = (ev.data or {}).n_requests or 1
          comp_done = 0
          require("ai.progress").mark(COMP, "completion")
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "MinuetRequestFinished",
        callback = function()
          comp_done = comp_done + 1
          if comp_done >= comp_expected then
            require("ai.progress").stop(COMP)
          end
        end,
      })

      -- Belt and braces: the inline interaction signals its own completion,
      -- and a stopped chat never emits RequestFinished at all.
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = {"CodeCompanionInlineFinished", "CodeCompanionChatStopped"},
        callback = function()
          require("ai.progress").stop_all()
        end,
      })
    end
  '';
}
