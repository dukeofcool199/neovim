{pkgs, ...}: {
  extraPlugins = with pkgs.vimPlugins; [
    vim-bookmarks
    telescope-vim-bookmarks-nvim
  ];

  extraConfigLua = ''
    local telescope_ok, telescope = pcall(require, "telescope")
    if telescope_ok then
      pcall(telescope.load_extension, "vim_bookmarks")
    end
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>Ba";
      action = "<cmd>BookmarkAnnotate<CR>";
      options = {
        desc = "Annotate";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>BF";
      action = "<cmd>Telescope vim_bookmarks all<CR>";
      options = {
        desc = "Find (All)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bf";
      action = "<cmd>Telescope vim_bookmarks current_file<CR>";
      options = {
        desc = "Find (Current File)";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bc";
      action = "<cmd>BookmarkClear<CR>";
      options = {
        desc = "Clear";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>BC";
      action = "<cmd>BookmarkClearAll<CR>";
      options = {
        desc = "Clear All";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bu";
      action = "<cmd>BookmarkMoveDown<CR>";
      options = {
        desc = "Move Down";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bd";
      action = "<cmd>BookmarkMoveUp<CR>";
      options = {
        desc = "Move Up";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bn";
      action = "<cmd>BookmarkNext<CR>";
      options = {
        desc = "Next";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bp";
      action = "<cmd>BookmarkPrev<CR>";
      options = {
        desc = "Previous";
        silent = true;
        noremap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>Bt";
      action = "<cmd>BookmarkToggle<CR>";
      options = {
        desc = "Toggle";
        silent = true;
        noremap = true;
      };
    }
  ];
}
