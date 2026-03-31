{pkgs, ...}: let
  prompt-yank = pkgs.vimUtils.buildVimPlugin {
    name = "prompt-yank.nvim";
    src = pkgs.fetchFromGitHub {
      owner = "polacekpavel";
      repo = "prompt-yank.nvim";
      rev = "5d278ca49bbb172b388287c6ae1aca4d466c1b36";
      sha256 = "sha256:18m3pwlla7qwn5zpd5nav4c5falc729kiqrc5xsw49wgrra31c1b";
    };
    doCheck = false;
  };
in {
  extraPlugins = [prompt-yank];

  extraConfigLua = ''
    require("prompt-yank").setup({
      output_style = "markdown",
      register = "+",
    })
  '';

  keymaps = [
    # Normal mode — file/context level
    {mode = "n"; key = "<leader>yy"; action = "<cmd>PromptYank<cr>";             options = {silent = true; noremap = true; desc = "Yank smart (file/selection)";};}
    {mode = "n"; key = "<leader>yf"; action = "<cmd>PromptYank function<cr>";    options = {silent = true; noremap = true; desc = "Yank function";};}
    {mode = "n"; key = "<leader>ym"; action = "<cmd>PromptYank multi<cr>";       options = {silent = true; noremap = true; desc = "Yank multi-file picker";};}
    {mode = "n"; key = "<leader>yd"; action = "<cmd>PromptYank diff<cr>";        options = {silent = true; noremap = true; desc = "Yank git diff";};}
    {mode = "n"; key = "<leader>yb"; action = "<cmd>PromptYank blame<cr>";       options = {silent = true; noremap = true; desc = "Yank git blame";};}
    {mode = "n"; key = "<leader>yt"; action = "<cmd>PromptYank tree<cr>";        options = {silent = true; noremap = true; desc = "Yank directory tree";};}
    {mode = "n"; key = "<leader>yr"; action = "<cmd>PromptYank remote<cr>";      options = {silent = true; noremap = true; desc = "Yank remote URL + code";};}
    {mode = "n"; key = "<leader>yR"; action = "<cmd>PromptYank definitions<cr>"; options = {silent = true; noremap = true; desc = "Yank file + related definitions";};}
    {mode = "n"; key = "<leader>yi"; action = "<cmd>PromptYank diagnostics<cr>"; options = {silent = true; noremap = true; desc = "Yank with diagnostics";};}

    # Visual mode — selection level
    {mode = "v"; key = "<leader>yy"; action = "<cmd>PromptYank selection<cr>";   options = {silent = true; noremap = true; desc = "Yank selection";};}
    {mode = "v"; key = "<leader>yd"; action = "<cmd>PromptYank diff<cr>";        options = {silent = true; noremap = true; desc = "Yank selection + diff";};}
    {mode = "v"; key = "<leader>yb"; action = "<cmd>PromptYank blame<cr>";       options = {silent = true; noremap = true; desc = "Yank selection + blame";};}
    {mode = "v"; key = "<leader>yt"; action = "<cmd>PromptYank tree<cr>";        options = {silent = true; noremap = true; desc = "Yank selection + tree path";};}
    {mode = "v"; key = "<leader>ye"; action = "<cmd>PromptYank diagnostics<cr>"; options = {silent = true; noremap = true; desc = "Yank selection + diagnostics";};}
    {mode = "v"; key = "<leader>yl"; action = "<cmd>PromptYank definitions<cr>"; options = {silent = true; noremap = true; desc = "Yank selection + LSP definitions";};}
  ];
}
