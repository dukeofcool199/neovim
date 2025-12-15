local op = require("opencode")

-- Enable auto-reload for OpenCode file edits
vim.o.autoread = true

-- Enhanced OpenCode configuration
vim.g.opencode_opts = {
  provider = {
    enabled = "kitty",
    terminal = {
      -- Use Neovim's built-in terminal
    }
  },
  -- Enable useful events
  events = {
    reload = true, -- Auto-reload buffers when OpenCode edits them
  },
  -- Configure prompts library
  prompts = {
    diagnostics = "Explain @diagnostics",
    diff = "Review the following git diff for correctness and readability: @diff",
    document = "Add comments documenting @this",
    explain = "Explain @this and its context",
    fix = "Fix @diagnostics",
    implement = "Implement @this",
    optimize = "Optimize @this for performance and readability",
    review = "Review @this for correctness and readability",
    test = "Add tests for @this"
  }
}

-- OpenCode keybindings using 'o' key chording
local which_key = require('which-key')

-- OpenCode chord mappings for normal mode (o + key)
which_key.register({
  -- Primary actions
  oa = { function() op.ask() end, "Ask OpenCode" },
  os = { function() op.select() end, "Select action" },
  op = { function() op.prompt("@this") end, "Prompt with context" },
  ot = { function() op.toggle() end, "Toggle terminal" },
  oq = { function() op.ask("@this: ", { submit = true }) end, "Quick ask with context" },

  -- Context-specific prompts
  ob = { function() op.prompt("@buffer") end, "Current buffer" },
  ov = { function() op.prompt("@visible") end, "Visible text" },
  od = { function() op.prompt("@diagnostics") end, "Diagnostics" },
  of = { function() op.prompt("@diff") end, "Git diff" },
  oQ = { function() op.prompt("@quickfix") end, "Quickfix list" },

  -- Built-in prompts
  ["or"] = { function() op.prompt("review") end, "Review code" },
  oR = { function() op.prompt("fix") end, "Fix diagnostics" },
  oo = { function() op.prompt("optimize") end, "Optimize code" },
  oT = { function() op.prompt("test") end, "Add tests" },
  oe = { function() op.prompt("explain") end, "Explain code" },
  oD = { function() op.prompt("document") end, "Document code" },
  oi = { function() op.prompt("implement") end, "Implement code" },

  -- Session management
  on = { function() op.command("session.new") end, "New session" },
  ol = { function() op.command("session.list") end, "List sessions" },
  oS = { function() op.command("session.share") end, "Share session" },
  oI = { function() op.command("session.interrupt") end, "Interrupt" },
  oc = { function() op.command("session.compact") end, "Compact session" },
  ou = { function() op.command("session.undo") end, "Undo" },
  oU = { function() op.command("session.redo") end, "Redo" },

  -- Navigation
  og = { function() op.command("session.first") end, "First message" },
  oG = { function() op.command("session.last") end, "Last message" },
  ok = { function() op.command("session.half.page.up") end, "Half page up" },
  oj = { function() op.command("session.half.page.down") end, "Half page down" },
  oK = { function() op.command("session.page.up") end, "Page up" },
  oJ = { function() op.command("session.page.down") end, "Page down" },

  -- Utility remaps to avoid conflicts
  ["+"] = { '<C-a>', 'Increment' },
  ["-"] = { '<C-x>', 'Decrement' },
}, { mode = "n", prefix = "<leader>" })

-- OpenCode chord mappings for visual mode (o + key)
which_key.register({
  -- Primary actions with selection
  oa = { function()
    op.ask()
    op.command("prompt.submit")
  end, "Ask with selection" },
  os = { function() op.select() end, "Select action" },
  op = { function() op.prompt("@this") end, "Prompt with selection" },
  oq = { function() op.ask("@this: ", { submit = true }) end, "Quick ask with selection" },

  -- Quick prompts for selected text
  ["or"] = { function() op.prompt("review") end, "Review selection" },
  oe = { function() op.prompt("explain") end, "Explain selection" },
  oR = { function() op.prompt("fix") end, "Fix selection" },
  oD = { function() op.prompt("document") end, "Document selection" },
  oT = { function() op.prompt("test") end, "Test selection" },
  oo = { function() op.prompt("optimize") end, "Optimize selection" },
  oi = { function() op.prompt("implement") end, "Implement selection" },
}, { mode = "v", prefix = "<leader>" })

-- Auto-handle OpenCode events
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent:*",
  callback = function(args)
    local event = args.data.event
    local port = args.data.port

    -- Handle specific events
    if event.type == "session.idle" then
      -- Optionally notify when OpenCode finishes responding
      -- vim.notify("OpenCode finished responding")
    elseif event.type == "file.edit" then
      -- File was edited by OpenCode - buffer will auto-reload
      vim.notify("File edited by OpenCode: " .. (event.path or "unknown"))
    elseif event.type == "permission.request" then
      -- Permission request will be handled by the plugin
      vim.notify("OpenCode permission request: " .. (event.description or "unknown"))
    end
  end,
})
