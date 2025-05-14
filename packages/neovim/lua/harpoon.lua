local harpoon = require("harpoon")

harpoon:setup({})

-- basic telescope configuration
local conf = require("telescope.config").values
local function toggle_telescope(harpoon_files)
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


require("which-key").register({
  l = {
    a = { function() harpoon:list():add() end, "add to harpoon list" },
    -- d = {
    --   function()
    --     local list = harpoon:list()
    --     local current = vim.fn.expand("%:p")
    --     for i = 1, list:length() do
    --       if list:get(i).value == current then
    --         list:remove(i)
    --         break
    --       end
    --     end
    --   end,
    --   "remove current harpoon item"
    -- },
    b = {
      function()
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
      end,
      "next harpoon item (wrap)"
    },

    n = {
      function()
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
      end,
      "previous harpoon item (wrap)"
    },
    d = { function() harpoon:list():clear() end, "clear harpoon items" },
    t = { function() toggle_telescope(harpoon:list()) end,
      "open harpoon list" }
  },
}, { mode = "n", prefix = "<leader>" })
