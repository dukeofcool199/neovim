# Intent-named AI bindings under <leader>a: avante, all of it. Ask, Edit
# (on the `edit` role's HTTP model), chats, context, history, quickfix into
# the prompt. Yank reaches prompt-yank. Lowercase acts with the registry's
# current backend and model; the capitalised sibling chooses first.
# Sidekick's terminal agents live under <leader>k (config/plugins/sidekick.nix).
{...}: {
  extraConfigLua = ''
    package.preload["ai.actions"] = function()
      local M = {}

      local function visual()
        return vim.fn.mode():match("^[vV\22]") ~= nil
      end

      -- Region --------------------------------------------------------------
      local FUNCTION_NODES = {
        ["function"] = true,
        arrow_function = true,
        class_declaration = true,
        func_literal = true,
        function_declaration = true,
        function_definition = true,
        function_item = true,
        local_function = true,
        method_declaration = true,
        method_definition = true,
      }

      --- Line range of the innermost function-ish node under the cursor.
      ---
      --- get_node reads the last parsed tree and answers nil when there isn't
      --- one yet, which is how a freshly opened buffer behaves, so parse first.
      local function enclosing_function()
        pcall(function()
          local parser = vim.treesitter.get_parser(0)
          if parser then
            parser:parse()
          end
        end)
        local ok, node = pcall(vim.treesitter.get_node)
        if not ok or not node then
          return nil
        end
        while node do
          if FUNCTION_NODES[node:type()] then
            local srow, _, erow, _ = node:range()
            return srow + 1, erow + 1
          end
          node = node:parent()
        end
        return nil
      end

      --- Put '< and '> around the region an action should act on: the live
      --- visual selection, or the enclosing function when there is none.
      --- Returns the line range.
      local function mark_region()
        if visual() then
          vim.cmd("normal! \27")
          return vim.fn.line("'<"), vim.fn.line("'>")
        end
        local first, last = enclosing_function()
        if not first then
          vim.notify("ai: no enclosing function, using whole buffer", vim.log.levels.WARN)
          first, last = 1, vim.api.nvim_buf_line_count(0)
        end
        local tail = vim.api.nvim_buf_get_lines(0, last - 1, last, false)[1] or ""
        vim.fn.setpos("'<", {0, first, 1, 0})
        vim.fn.setpos("'>", {0, last, math.max(1, #tail), 0})
        return first, last
      end

      -- Avante --------------------------------------------------------------
      -- Nothing is set up until the agent role has a backend, so on a project
      -- without one every avante key offers the picker instead.
      local function ready()
        if require("ai.avante").ensure() then
          return true
        end
        vim.notify(
          "ai: no agent backend -- pick one, or put require('ai').setup({agent = {backend = ..., model = ...}}) in .nvim.lua",
          vim.log.levels.WARN
        )
        M.ask_pick()
        return false
      end

      local function api()
        return require("avante.api")
      end

      --- Toggle the sidebar; with a selection, ask about it.
      function M.ask()
        if not ready() then
          return
        end
        if visual() then
          api().ask()
        else
          vim.cmd("AvanteToggle")
        end
      end

      --- Backend first, then a model that backend can reach, then open.
      function M.ask_pick()
        local ai = require("ai")
        vim.ui.select(ai.backends(), {prompt = "AI: agent backend"}, function(backend)
          if not backend then
            return
          end
          ai.set("agent", {backend = backend})
          ai.pick("agent", function()
            if require("ai.avante").ensure() then
              vim.cmd("AvanteAsk")
            end
          end)
        end)
      end

      --- Rewrite the selection or enclosing function in place, on the
      --- `edit` role's model.
      function M.edit()
        local first, last = mark_region()
        if ready() then
          require("ai.avante").edit(first, last)
        end
      end

      --- Endpoint first (ollama, opencode-go, ...), then a model it serves.
      function M.edit_pick()
        local first, last = mark_region()
        local ai = require("ai")
        vim.ui.select(ai.http_backends(), {prompt = "AI: edit backend"}, function(backend)
          if not backend then
            return
          end
          ai.set("edit", {backend = backend})
          ai.pick("edit", function()
            if ready() then
              require("ai.avante").edit(first, last)
            end
          end)
        end)
      end

      local function command(cmd)
        return function()
          if ready() then
            vim.cmd(cmd)
          end
        end
      end

      local function call(fn)
        return function()
          if ready() then
            api()[fn]()
          end
        end
      end

      M.new = command("AvanteChatNew")
      M.history = command("AvanteHistory")
      M.focus = command("AvanteFocus")
      M.stop = command("AvanteStop")
      M.clear = command("AvanteClear")
      M.refresh = command("AvanteRefresh")
      M.repomap = command("AvanteShowRepoMap")
      M.add_buffer = call("add_buffer_files")
      M.zen = call("zen_mode")

      function M.add_all_buffers()
        if not ready() then
          return
        end
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          local name = vim.api.nvim_buf_get_name(buf)
          if vim.bo[buf].buflisted and name ~= "" and vim.fn.filereadable(name) == 1 then
            api().add_selected_file(name)
          end
        end
      end

      --- Live model change. ACP sessions switch in place; the environment
      --- the registry sets only reaches the next chat, so this is the way to
      --- change a running claude or opencode. HTTP backends use avante's list.
      function M.models()
        if not ready() then
          return
        end
        local r = require("ai").role("agent")
        if r and r.transport == "acp" then
          api().select_acp_model()
        else
          api().select_model()
        end
      end

      M.acp_mode = call("select_acp_mode")

      -- Quickfix ------------------------------------------------------------
      local MAX_ITEMS = 200

      --- A list as a markdown block: the title, then one `- path:line:col
      --- [E] text` per entry. Returns the block and the readable files it
      --- names, for the sidebar's context.
      local function list_block(info, label)
        local cwd = vim.fs.normalize(vim.fn.getcwd())
        local lines, files, seen = {}, {}, {}
        local title = info.title or ""
        if title:match("^:%S") then
          title = ""
        end
        table.insert(lines, label .. (title ~= "" and (": " .. title) or ""))
        for i, item in ipairs(info.items) do
          if i > MAX_ITEMS then
            table.insert(lines, ("- ... and %d more"):format(#info.items - MAX_ITEMS))
            break
          end
          local name = item.filename
          if (not name or name == "") and item.bufnr and item.bufnr > 0 then
            name = vim.api.nvim_buf_get_name(item.bufnr)
          end
          local shown = "[No Name]"
          if name and name ~= "" then
            name = vim.fs.normalize(name)
            shown = name:sub(1, #cwd + 1) == cwd .. "/" and name:sub(#cwd + 2) or name
            if not seen[name] and vim.fn.filereadable(name) == 1 then
              seen[name] = true
              table.insert(files, name)
            end
          end
          local where = shown
          if (item.lnum or 0) > 0 then
            where = where .. ":" .. item.lnum
            if (item.col or 0) > 0 then
              where = where .. ":" .. item.col
            end
          end
          local kind = (item.type and item.type ~= "") and (" [" .. item.type:upper() .. "]") or ""
          local text = (item.text or ""):gsub("%s+$", "")
          text = vim.trim(text)
          table.insert(lines, ("- %s%s%s"):format(where, kind, text ~= "" and (" " .. text) or ""))
        end
        return table.concat(lines, "\n"), files
      end

      --- The quickfix list (or the window's location list) into the agent's
      --- prompt, unsent, its files attached.
      function M.quickfix(loclist)
        local info = loclist and vim.fn.getloclist(0, {items = 0, title = 0}) or vim.fn.getqflist({items = 0, title = 0})
        if #(info.items or {}) == 0 then
          vim.notify("ai: " .. (loclist and "location list" or "quickfix list") .. " is empty", vim.log.levels.WARN)
          return
        end
        if not ready() then
          return
        end
        local text, files = list_block(info, loclist and "Location list" or "Quickfix")
        require("ai.avante").stage(text, files)
      end

      -- Yank ----------------------------------------------------------------
      local YANK = {
        {"Smart (file or selection)", ""},
        {"Function", "function"},
        {"Selection", "selection"},
        {"Git diff", "diff"},
        {"Git blame", "blame"},
        {"Directory tree", "tree"},
        {"Remote URL + code", "remote"},
        {"File + related definitions", "definitions"},
        {"With diagnostics", "diagnostics"},
        {"Multiple files...", "multi"},
      }

      --- vim.ui.select drops visual mode, so the selection is restored with
      --- `gv` before the command runs.
      function M.yank_pick()
        local was_visual = visual()
        if was_visual then
          vim.cmd("normal! \27")
        end
        local labels = vim.tbl_map(function(e)
          return e[1]
        end, YANK)
        vim.ui.select(labels, {prompt = "AI: yank context"}, function(_, idx)
          if not idx then
            return
          end
          if was_visual then
            vim.cmd("normal! gv")
          end
          local arg = YANK[idx][2]
          vim.cmd("PromptYank" .. (arg ~= "" and (" " .. arg) or ""))
        end)
      end

      -- Control -------------------------------------------------------------
      local SETTINGS = {
        {"Agent: backend and model...", "lua require('ai.actions').ask_pick()"},
        {"Agent: model of the running session", "lua require('ai.actions').models()"},
        {"Agent: mode of the running ACP session", "lua require('ai.actions').acp_mode()"},
        {"Agent: clear chat", "lua require('ai.actions').clear()"},
        {"Agent: repo map", "lua require('ai.actions').repomap()"},
        {"Model for any role...", "AiPick"},
        {"Status", "AiStatus"},
        {"Doctor (check models suit their roles)", "AiDoctor"},
        {"Credentials", "AiAuth"},
        {"Credentials (re-check)", "AiAuth!"},
        {"Reset overrides", "AiReset"},
      }

      function M.settings_pick()
        local labels = vim.tbl_map(function(e)
          return e[1]
        end, SETTINGS)
        vim.ui.select(labels, {prompt = "AI: models and credentials"}, function(_, idx)
          if idx then
            vim.cmd(SETTINGS[idx][2])
          end
        end)
      end

      return M
    end
  '';

  keymaps = let
    act = fn: {__raw = "function() require('ai.actions').${fn} end";};
    map = mode: key: fn: desc: {
      inherit mode key;
      action = act fn;
      options = {
        inherit desc;
        silent = true;
        noremap = true;
      };
    };
    nv = ["n" "v"];
  in [
    (map nv "<leader>aa" "ask()" "Ask (toggle sidebar; selection asks about it)")
    (map "n" "<leader>aA" "ask_pick()" "Ask (choose backend and model)")
    (map nv "<leader>ae" "edit()" "Edit function/selection in place")
    (map nv "<leader>aE" "edit_pick()" "Edit (choose backend and model)")
    (map "n" "<leader>an" "new()" "New chat")
    (map "n" "<leader>ah" "history()" "History of chats")
    (map "n" "<leader>af" "focus()" "Focus sidebar / code")
    (map "n" "<leader>ab" "add_buffer()" "Buffer into context")
    (map "n" "<leader>aB" "add_all_buffers()" "All buffers into context")
    (map "n" "<leader>aq" "quickfix()" "Quickfix list into the prompt")
    (map "n" "<leader>aQ" "quickfix(true)" "Location list into the prompt")
    (map "n" "<leader>ax" "stop()" "Stop the request")
    (map "n" "<leader>ac" "clear()" "Clear the chat")
    (map "n" "<leader>ar" "refresh()" "Refresh sidebar")
    (map "n" "<leader>aR" "repomap()" "Repo map")
    (map "n" "<leader>az" "zen()" "Zen: chat full view")
    (map "n" "<leader>aM" "models()" "Model of the running session")
    (map "n" "<leader>am" "settings_pick()" "Models and credentials")
    (map nv "<leader>ay" "yank_pick()" "Yank context")
  ];
}
