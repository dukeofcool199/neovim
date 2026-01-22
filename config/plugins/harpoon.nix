{ ... }:
{
  plugins.harpoon = {
    enable = true;
    enableTelescope = true;
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>la";
      action.__raw = ''function() require("harpoon"):list():add() end'';
      options = { desc = "Add to harpoon list"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>lb";
      action.__raw = ''
        function()
          local harpoon = require("harpoon")
          local list = harpoon:list()
          local count = list:length()
          if count == 0 then return end

          local current = vim.fn.expand("%")
          local next_index = 1

          for i = 1, count do
            if list:get(i).value == current then
              next_index = (i % count) + 1
              break
            end
          end

          list:select(next_index)
        end
      '';
      options = { desc = "Next harpoon item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>ln";
      action.__raw = ''
        function()
          local harpoon = require("harpoon")
          local list = harpoon:list()
          local count = list:length()
          if count == 0 then return end

          local current = vim.fn.expand("%")
          local prev_index = count

          for i = 1, count do
            if list:get(i).value == current then
              prev_index = (i - 2 + count) % count + 1
              break
            end
          end

          list:select(prev_index)
        end
      '';
      options = { desc = "Previous harpoon item (wrap)"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>ld";
      action.__raw = ''function() require("harpoon"):list():clear() end'';
      options = { desc = "Clear harpoon items"; silent = true; };
    }
    {
      mode = "n";
      key = "<leader>lt";
      action.__raw = ''
        function()
          local harpoon = require("harpoon")
          local conf = require("telescope.config").values
          local harpoon_files = harpoon:list()

          local file_paths = {}
          for _, item in ipairs(harpoon_files.items) do
            table.insert(file_paths, item.value)
          end

          require("telescope.pickers").new({}, {
            prompt_title = "Harpoon",
            finder = require("telescope.finders").new_table({
              results = file_paths,
            }),
            previewer = conf.file_previewer({}),
            sorter = conf.generic_sorter({}),
          }):find()
        end
      '';
      options = { desc = "Open harpoon list"; silent = true; };
    }
  ];
}
