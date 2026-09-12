# Intent-named AI bindings. Every map here says what you want done, never
# which plugin does it: Ask, Edit and Task reach codecompanion, Do and Send
# reach sidekick's agent terminals, Completion and Next reach minuet, Yank
# reaches prompt-yank. Lowercase acts with the registry's current model; the
# capitalised sibling chooses first.
#
# Edit is freeform -- you type the instruction. Task is the opposite: a named
# prompt from config/ai/prompts, written once so a small local model gets the
# same brief every time.
{...}: {
  extraConfigLua = ''
    package.preload["ai.actions"] = function()
      local M = {}

      local function cli()
        return require("sidekick.cli")
      end

      -- Ask ---------------------------------------------------------------
      function M.ask()
        vim.cmd("CodeCompanionChat")
      end

      function M.ask_pick()
        require("ai").pick("ask", function()
          vim.cmd("CodeCompanionChat")
        end)
      end

      -- Edit --------------------------------------------------------------
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

      --- Put '< and '> around the region an AI action should act on: the live
      --- visual selection, or the enclosing function when there is none.
      ---
      --- The marks are the load-bearing part, not the `:range`. codecompanion
      --- treats any range as "visual" but then reads the marks rather than the
      --- range itself, so a command built from line numbers alone sends
      --- whatever happened to be selected last.
      local function mark_region()
        if vim.fn.mode():match("^[vV\22]") then
          vim.cmd("normal! \27")
          return
        end
        local first, last = enclosing_function()
        if not first then
          vim.notify("ai: no enclosing function, using whole buffer", vim.log.levels.WARN)
          first, last = 1, vim.api.nvim_buf_line_count(0)
        end
        local tail = vim.api.nvim_buf_get_lines(0, last - 1, last, false)[1] or ""
        vim.fn.setpos("'<", {0, first, 1, 0})
        vim.fn.setpos("'>", {0, last, math.max(1, #tail), 0})
      end

      --- Inline edit over the enclosing function, falling back to the buffer.
      function M.edit()
        mark_region()
        vim.api.nvim_feedkeys(":'<,'>CodeCompanion ", "n", false)
      end

      function M.edit_pick()
        require("ai").pick("edit", function()
          M.edit()
        end)
      end

      -- Task --------------------------------------------------------------
      -- Named prompts from codecompanion's library: the ones that rewrite a
      -- selection run on the `edit` model, the ones that open a chat run on
      -- `ask`. Drop a markdown file into .codecompanion/prompts and it joins
      -- the list.

      local function run_task(alias)
        require("codecompanion").prompt(alias, {range = 2})
      end

      -- Builtins that config/ai/prompts covers better, hidden so the list holds
      -- one entry per intent.
      local SUPERSEDED = {tests = true}

      local function tasks()
        local palette = require("codecompanion.action_palette")
        local context = require("codecompanion.utils.context").get(0)
        local found = {}
        for _, item in ipairs(palette.get_cached_items(context)) do
          local alias = item.opts and item.opts.alias
          if alias and not SUPERSEDED[alias] and (item.interaction == "inline" or item.interaction == "chat") then
            table.insert(found, item)
          end
        end
        table.sort(found, function(a, b)
          if a.interaction ~= b.interaction then
            return a.interaction == "inline"
          end
          return a.name < b.name
        end)
        return found
      end

      local PLACEMENT = {
        new = "new buffer",
        before = "above selection",
        add = "below selection",
      }

      --- Where a task's output lands, and which role pays for it.
      local function destination(item)
        if item.interaction ~= "inline" then
          return "chat", "ask"
        end
        return PLACEMENT[item.opts.placement] or "replace selection", "edit"
      end

      function M.task(alias)
        mark_region()
        run_task(alias)
      end

      local function task_menu()
        local found = tasks()
        if #found == 0 then
          vim.notify("ai: no tasks in the prompt library", vim.log.levels.WARN)
          return
        end

        local ai = require("ai")
        local name_w, where_w = 0, 0
        local rows = {}
        for _, item in ipairs(found) do
          local where, role = destination(item)
          name_w = math.max(name_w, vim.fn.strdisplaywidth(item.name))
          where_w = math.max(where_w, vim.fn.strdisplaywidth(where))
          table.insert(rows, {item.name, where, ai.describe(role)})
        end
        local fmt = ("%%-%ds   %%-%ds   %%s"):format(name_w, where_w)
        local labels = vim.tbl_map(function(row)
          return fmt:format(row[1], row[2], row[3])
        end, rows)

        vim.ui.select(labels, {prompt = "AI: task"}, function(_, idx)
          if idx then
            run_task(found[idx].opts.alias)
          end
        end)
      end

      --- Both entry points mark the region first: vim.ui.select drops visual
      --- mode, so by the time a menu answers there is nothing left to read.
      function M.task_pick()
        mark_region()
        task_menu()
      end

      --- For the tasks a small model cannot hold: raise the edit model, then
      --- choose. The choice sticks for the session, the same as <leader>aE.
      function M.task_pick_model()
        mark_region()
        require("ai").pick("edit", function()
          task_menu()
        end)
      end

      -- Do ----------------------------------------------------------------
      function M.agent()
        local r = require("ai").role("agent")
        cli().toggle({name = (r and r.command) or "claude", focus = true})
      end

      function M.agent_pick()
        cli().select()
      end

      -- Completion --------------------------------------------------------
      function M.complete_toggle()
        require("minuet-project").toggle()
      end

      function M.next_predict()
        require("minuet.duet").action.predict()
      end

      function M.next_apply()
        require("minuet.duet").action.apply()
      end

      -- Send --------------------------------------------------------------
      function M.send(what)
        cli().send({msg = what})
      end

      local SEND = {
        {"This (cursor context)", "{this}"},
        {"Selection", "{selection}"},
        {"Whole file", "{file}"},
      }

      function M.send_pick()
        local labels = vim.tbl_map(function(e)
          return e[1]
        end, SEND)
        table.insert(labels, "Prompt library...")
        vim.ui.select(labels, {prompt = "AI: send to agent"}, function(_, idx)
          if not idx then
            return
          end
          if idx > #SEND then
            cli().prompt()
          else
            M.send(SEND[idx][2])
          end
        end)
      end

      -- Yank --------------------------------------------------------------
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
        local visual = vim.fn.mode():match("^[vV\22]") ~= nil
        if visual then
          vim.cmd("normal! \27")
        end
        local labels = vim.tbl_map(function(e)
          return e[1]
        end, YANK)
        vim.ui.select(labels, {prompt = "AI: yank context"}, function(_, idx)
          if not idx then
            return
          end
          if visual then
            vim.cmd("normal! gv")
          end
          local arg = YANK[idx][2]
          vim.cmd("PromptYank" .. (arg ~= "" and (" " .. arg) or ""))
        end)
      end

      -- Control -----------------------------------------------------------
      local SETTINGS = {
        {"Model...", "AiPick"},
        {"Status", "AiStatus"},
        {"Doctor (check models suit their roles)", "AiDoctor"},
        {"Credentials", "AiAuth"},
        {"Credentials (re-check)", "AiAuth!"},
        {"Tier: small", "AiTier small"},
        {"Tier: big", "AiTier big"},
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
  in [
    {
      mode = ["n" "v"];
      key = "<leader>aa";
      action = "<cmd>CodeCompanionChat<cr>";
      options = {
        desc = "Ask";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>aA";
      action = act "ask_pick()";
      options = {
        desc = "Ask (choose model)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "v";
      key = "<leader>ae";
      action = ":CodeCompanion ";
      options = {
        desc = "Edit selection";
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ae";
      action = act "edit()";
      options = {
        desc = "Edit function";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>aE";
      action = act "edit_pick()";
      options = {
        desc = "Edit (choose model)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = ["n" "v"];
      key = "<leader>at";
      action = act "task_pick()";
      options = {
        desc = "Task (document, fix, tests, review...)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = ["n" "v"];
      key = "<leader>aT";
      action = act "task_pick_model()";
      options = {
        desc = "Task (choose model)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ad";
      action = act "agent()";
      options = {
        desc = "Do (agent terminal)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>aD";
      action = act "agent_pick()";
      options = {
        desc = "Do (choose agent)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ac";
      action = act "complete_toggle()";
      options = {
        desc = "Completion toggle";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>an";
      action = act "next_predict()";
      options = {
        desc = "Next edit: predict";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>aN";
      action = act "next_apply()";
      options = {
        desc = "Next edit: apply";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>as";
      action = act "send('{this}')";
      options = {
        desc = "Send context to agent";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "v";
      key = "<leader>as";
      action = act "send('{selection}')";
      options = {
        desc = "Send selection to agent";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = ["n" "v"];
      key = "<leader>aS";
      action = act "send_pick()";
      options = {
        desc = "Send... (choose what)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = ["n" "v"];
      key = "<leader>ay";
      action = act "yank_pick()";
      options = {
        desc = "Yank context";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>am";
      action = act "settings_pick()";
      options = {
        desc = "Models and credentials";
        silent = true;
        noremap = true;
      };
    }
  ];
}
