{ ... }:
{
  plugins.which-key = {
    enable = true;
    settings = {
      spec = [
        # Top-level leader groups
        { __unkeyed-1 = "<leader>b"; group = "Buffer"; }
        { __unkeyed-1 = "<leader>B"; group = "Bookmarks"; }
        { __unkeyed-1 = "<leader>c"; group = "Code"; }
        { __unkeyed-1 = "<leader>f"; group = "File"; }
        { __unkeyed-1 = "<leader>g"; group = "Git"; }
        { __unkeyed-1 = "<leader>h"; group = "Git Hunk"; }
        { __unkeyed-1 = "<leader>l"; group = "Harpoon List"; }
        { __unkeyed-1 = "<leader>m"; group = "Multi Cursor"; }
        { __unkeyed-1 = "<leader>n"; group = "New"; }
        { __unkeyed-1 = "<leader>q"; group = "Quit"; }
        { __unkeyed-1 = "<leader>s"; group = "Split"; }
        { __unkeyed-1 = "<leader>t"; group = "Toggle/Tab"; }
        { __unkeyed-1 = "<leader>w"; group = "Workspace"; }
        { __unkeyed-1 = "<leader>z"; group = "Zen"; }
        { __unkeyed-1 = "<leader><leader>"; group = "Hop"; }
      ];
    };
  };
}
