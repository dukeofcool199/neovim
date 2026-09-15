# The parts of <leader>a that belong to no single plugin: Yank reaches
# prompt-yank, and the settings picker reaches the registry's :Ai* commands.
# Sidekick's terminal agents own the rest of <leader>a
# (config/plugins/sidekick.nix); 99 lives under <leader>9.
{...}: {
  extraConfigLua = ''
    package.preload["ai.actions"] = function()
      local M = {}

      local function visual()
        return vim.fn.mode():match("^[vV\22]") ~= nil
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
    (map nv "<leader>ay" "yank_pick()" "Yank context")
    (map "n" "<leader>am" "settings_pick()" "Models and credentials")
  ];
}
