# Working/idle state for the sidekick CLI agents.
#
# The agents run in a float you toggle away, so the moment one is hidden there
# is nothing on screen saying whether it is still going. Each tool announces
# itself differently, so three signals feed the one answer per session:
#
#   title     a spinner glyph at the head of the OSC title        (claude)
#   progress  OSC 9;4;3 while a turn runs, 9;4;0 when it ends     (pi)
#   screen    the tool's own footer, read off the terminal        (opencode, aider)
#
# The first two arrive as events; only `screen` needs the poll below. A
# terminal buffer keeps updating while its window is hidden, which is what
# makes reading the screen work in the case that matters.
#
# Two statusline segments come out of it -- a spinner on whatever is working,
# and a mark on an agent that finished while its terminal was hidden, which
# stays up until the terminal is opened again.
#
# A blocked agent (waiting on a permission prompt) stops spinning too, so it
# reads as finished here. That is the intent: both mean the agent wants you.
{...}: {
  extraConfigLua = ''
    package.preload["ai.cli"] = function()
      local M = {}

      local SPIN_MS = 100
      local IDLE_MS = 500
      local SCREEN_LINES = 12
      local QUIET_MS = 2000

      --- Which signals speak for which tool. Screen patterns are Lua patterns
      --- matched against lowercased lines, and follow herdr's detection rules.
      --- A tool with no entry gets the two event-driven signals and no guessed
      --- screen rule.
      local RULES = {
        claude = {title = true, progress = true},
        pi = {progress = true, screen = {working = {"working%.%.%.", "^── .- working "}}},
        opencode = {
          screen = {
            working = {
              "esc to interrupt",
              "esc again to interrupt",
              "ctrl%+c to interrupt",
              "■■■■",
              "⬝⬝⬝⬝",
            },
          },
        },
        -- aider has no marker of its own once the response starts streaming,
        -- so it is working whenever its prompt is out of sight and the screen
        -- is still moving. The quiescence guard is what keeps a static
        -- non-prompt screen -- a pager, a dumped diff -- from spinning forever.
        aider = {screen = {idle = {"^%s*>%s", "^multi>"}}},
      }
      local DEFAULT = {title = true, progress = true}

      ---@class ai.cli.Agent
      ---@field tool string
      ---@field working boolean
      ---@field since integer  -- vim.uv.now() when the state last changed
      ---@field unseen boolean -- stopped with its terminal hidden, not looked at yet
      ---@field screen string  -- last scrape, to tell a moving screen from a still one
      ---@field screen_at integer

      local agents = {} ---@type table<string, ai.cli.Agent>
      local progress = {} ---@type table<integer, boolean> -- terminal buf -> OSC 9;4 state
      local timer ---@type uv.uv_timer_t?
      local timer_ms ---@type integer?
      local spinning = false

      local function terminals()
        local ok, Terminal = pcall(require, "sidekick.cli.terminal")
        return ok and Terminal.terminals or {}
      end

      local function tool_name(term)
        local tool = term.tool
        return type(tool) == "table" and tool.name or tostring(tool)
      end

      local function rules(tool)
        return RULES[tool] or DEFAULT
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
      local function title_working(title)
        if type(title) ~= "string" or vim.fn.strgetchar(title, 1) ~= 32 then
          return false
        end
        local glyph = vim.fn.strgetchar(title, 0)
        return (glyph >= 0x2800 and glyph <= 0x28FF) or (glyph >= 0x25D0 and glyph <= 0x25D3)
      end

      --- The bottom SCREEN_LINES non-empty lines, the region herdr's screen
      --- rules read. Lowercased, so the patterns can be too.
      local function screen_lines(term)
        local buf = term.buf
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then
          return {}
        end
        local n = vim.api.nvim_buf_line_count(buf)
        local raw = vim.api.nvim_buf_get_lines(buf, math.max(0, n - SCREEN_LINES * 4), n, false)
        local out = {}
        for i = #raw, 1, -1 do
          if raw[i]:find("%S") then
            table.insert(out, 1, raw[i]:lower())
            if #out >= SCREEN_LINES then
              break
            end
          end
        end
        return out
      end

      local function matches(lines, pats)
        for _, line in ipairs(lines) do
          for _, pat in ipairs(pats) do
            if line:find(pat) then
              return true
            end
          end
        end
        return false
      end

      local function is_working(agent, term)
        local r = rules(agent.tool)
        if r.title and title_working(title_of(term)) then
          return true
        end
        if r.progress and progress[term.buf] then
          return true
        end
        if not r.screen then
          return false
        end

        local lines = screen_lines(term)
        local text = table.concat(lines, "\n")
        if text ~= agent.screen then
          agent.screen, agent.screen_at = text, vim.uv.now()
        end

        if r.screen.working then
          return matches(lines, r.screen.working)
        end
        return not matches(lines, r.screen.idle)
          and (vim.uv.now() - agent.screen_at) < (r.screen.quiet_ms or QUIET_MS)
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
        timer_ms = nil
      end

      --- Spinner rate while something works, a slower poll while a tool that
      --- only shows on screen is merely open, and nothing otherwise. The
      --- finished mark is static text and needs no ticking.
      local function tick()
        spinning = false
        for _, a in pairs(agents) do
          spinning = spinning or a.working
        end

        local polls = false
        for _, term in pairs(terminals()) do
          polls = polls or rules(tool_name(term)).screen ~= nil
        end

        local want = spinning and SPIN_MS or (polls and IDLE_MS or nil)
        if not want then
          return stop_timer()
        end
        if timer and timer_ms == want then
          return
        end

        stop_timer()
        timer_ms = want
        timer = vim.uv.new_timer()
        timer:start(
          want,
          want,
          vim.schedule_wrap(function()
            M.sync()
            if spinning then
              refresh()
            end
          end)
        )
      end

      --- Record an OSC 9;4 progress state for a terminal buffer. nvim reports
      --- the sequence through TermRequest and keeps no variable for it.
      function M.progress(buf, on)
        progress[buf] = on or nil
      end

      function M.sync()
        local changed, live, bufs = false, {}, {}

        for id, term in pairs(terminals()) do
          live[id] = true
          if term.buf then
            bufs[term.buf] = true
          end
          local a = agents[id]
          if not a then
            local now = vim.uv.now()
            a = {tool = tool_name(term), working = false, since = now, unseen = false, screen_at = now}
            agents[id] = a
          end
          local working = is_working(a, term)
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

        for buf in pairs(progress) do
          if not bufs[buf] then
            progress[buf] = nil
          end
        end

        if changed then
          refresh()
        end
        tick()
      end

      --- Is any agent working right now?
      function M.working()
        for _, a in pairs(agents) do
          if a.working then
            return true
          end
        end
        return false
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
        local ok, progress_mod = pcall(require, "ai.progress")
        return ok and progress_mod.frame() or "*"
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
      -- only current once the handler has run. It also carries OSC 9;4, which
      -- nvim passes through without recording anywhere.
      vim.api.nvim_create_autocmd("TermRequest", {
        group = group,
        callback = function(ev)
          local seq = ev.data and ev.data.sequence
          local state = type(seq) == "string" and seq:match("^\27]9;4;(%d)")
          if state then
            require("ai.cli").progress(ev.buf, state ~= "0")
          end
          sync()
        end,
      })

      vim.api.nvim_create_autocmd("TermClose", {group = group, callback = sync})

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
