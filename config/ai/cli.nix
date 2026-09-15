# Working/idle state for the sidekick CLI agents.
#
# The agents run in a float you toggle away, so the moment one is hidden there
# is nothing on screen saying whether it is still going. The agents do say so,
# in their terminal title: a spinner glyph while they work, U+2733 when they
# are back at the prompt. This tracks that per session and turns it into two
# statusline segments -- a spinner on whatever is working, and a mark on an
# agent that finished while its terminal was hidden, which stays up until the
# terminal is opened again.
#
# A blocked agent (waiting on a permission prompt) stops spinning too, so it
# reads as finished here. That is the intent: both mean the agent wants you.
{...}: {
  extraConfigLua = ''
    package.preload["ai.cli"] = function()
      local M = {}

      local SPIN_MS = 100

      ---@class ai.cli.Agent
      ---@field tool string
      ---@field working boolean
      ---@field since integer  -- vim.uv.now() when the state last changed
      ---@field unseen boolean -- stopped with its terminal hidden, not looked at yet

      local agents = {} ---@type table<string, ai.cli.Agent>
      local timer ---@type uv.uv_timer_t?

      local function terminals()
        local ok, Terminal = pcall(require, "sidekick.cli.terminal")
        return ok and Terminal.terminals or {}
      end

      local function tool_name(term)
        local tool = term.tool
        return type(tool) == "table" and tool.name or tostring(tool)
      end

      local function title_of(term)
        local buf = term.buf
        if buf and vim.api.nvim_buf_is_valid(buf) then
          return vim.b[buf].term_title
        end
      end

      --- A braille or half-circle spinner at the head of the title. The glyph
      --- ranges are herdr's, from its `osc_title_working` detection rule:
      --- braille up to claude 2.1.227, half-circles from 2.1.228.
      ---@param title? string
      function M.is_working(title)
        if type(title) ~= "string" or vim.fn.strgetchar(title, 1) ~= 32 then
          return false
        end
        local glyph = vim.fn.strgetchar(title, 0)
        return (glyph >= 0x2800 and glyph <= 0x28FF) or (glyph >= 0x25D0 and glyph <= 0x25D3)
      end

      --- Title of the most recently active agent terminal, if any. Read live
      --- off the terminals rather than out of the table below, so a caller on
      --- the same autocmd cannot race the bookkeeping.
      function M.title()
        local title, atime
        for _, term in pairs(terminals()) do
          local t = title_of(term)
          if t and t ~= "" and (not atime or (term.atime or 0) >= atime) then
            title, atime = t, term.atime or 0
          end
        end
        return title
      end

      --- Is any agent working right now?
      function M.working()
        for _, term in pairs(terminals()) do
          if M.is_working(title_of(term)) then
            return true
          end
        end
        return false
      end

      local function refresh()
        pcall(function()
          require("lualine").refresh()
        end)
      end

      local function stop_timer()
        if timer then
          timer:stop()
          if not timer:is_closing() then
            timer:close()
          end
          timer = nil
        end
      end

      --- Animate only while something is spinning; the finished mark is static
      --- text and needs no ticking.
      local function tick()
        local spinning = false
        for _, a in pairs(agents) do
          spinning = spinning or a.working
        end
        if not spinning then
          return stop_timer()
        end
        if timer then
          return
        end
        timer = vim.uv.new_timer()
        timer:start(
          SPIN_MS,
          SPIN_MS,
          vim.schedule_wrap(function()
            M.sync()
            refresh()
          end)
        )
      end

      function M.sync()
        local changed, live = false, {}

        for id, term in pairs(terminals()) do
          live[id] = true
          local a = agents[id]
          if not a then
            a = {tool = tool_name(term), working = false, since = vim.uv.now(), unseen = false}
            agents[id] = a
          end
          local working = M.is_working(title_of(term))
          if working ~= a.working then
            a.working = working
            a.since = vim.uv.now()
            -- Stopped out of sight: hold the result up until it is looked at.
            a.unseen = not working and not term:is_open()
            changed = true
          elseif a.unseen and term:is_open() then
            a.unseen = false
            changed = true
          end
        end

        for id in pairs(agents) do
          if not live[id] then
            agents[id] = nil
            changed = true
          end
        end

        if changed then
          refresh()
        end
        tick()
      end

      local function ago(ms)
        local secs = math.floor(ms / 1000)
        if secs < 1 then
          return ""
        elseif secs < 60 then
          return (" %ds"):format(secs)
        end
        return (" %dm"):format(math.floor(secs / 60))
      end

      local function frame()
        local ok, progress = pcall(require, "ai.progress")
        return ok and progress.frame() or "*"
      end

      --- Statusline fragment. `kind` is "working" for the agents running right
      --- now, "done" for ones that stopped while you were not looking.
      ---@param kind "working"|"done"
      function M.status(kind)
        local ids = vim.tbl_keys(agents)
        table.sort(ids)
        local parts = {}
        for _, id in ipairs(ids) do
          local a = agents[id]
          local since = ago(vim.uv.now() - a.since)
          if kind == "working" and a.working then
            parts[#parts + 1] = frame() .. " " .. a.tool .. since
          elseif kind == "done" and a.unseen then
            parts[#parts + 1] = "✓ " .. a.tool .. since
          end
        end
        return table.concat(parts, "  ")
      end

      return M
    end

    _G.ai_cli_status = function(kind)
      return require("ai.cli").status(kind)
    end

    _G.ai_cli_active = function(kind)
      return require("ai.cli").status(kind) ~= ""
    end

    do
      local group = vim.api.nvim_create_augroup("AiCli", {clear = true})

      local function sync()
        vim.schedule(function()
          require("ai.cli").sync()
        end)
      end

      -- TermRequest carries the OSC that sets b:term_title, so the variable is
      -- only current once the handler has run.
      vim.api.nvim_create_autocmd({"TermRequest", "TermClose"}, {group = group, callback = sync})

      -- Opening the terminal is what marks a finished agent as seen.
      vim.api.nvim_create_autocmd({"WinEnter", "WinClosed"}, {group = group, callback = sync})

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = {"SidekickCliAttach", "SidekickCliDetach"},
        callback = sync,
      })
    end
  '';
}
