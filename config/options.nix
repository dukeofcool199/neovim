{ ... }: {
  # Global variables
  globals = {
    mapleader = " ";
    # Disable bookmark keybindings (from init.vim)
    bookmark_no_default_key_mappings = 1;
  };

  # Editor options
  opts = {
    # Compatibility
    compatible = false;

    # Status line
    laststatus = 3;

    # Colors
    termguicolors = true;
    timeoutlen = 250;

    # Indentation
    autoindent = true;
    tabstop = 2;
    shiftwidth = 2;
    expandtab = true;

    # Line numbers
    number = true;
    relativenumber = false;

    # Cursor
    cursorline = true;

    # Scrolling
    scrolloff = 10;

    # Text wrapping
    wrap = true;
    linebreak = true;

    # Sign column - prevent flashing with gitsigns
    signcolumn = "yes";

    # Disable mouse (professionals only)
    mouse = "";

    # Completion menu
    completeopt = "menu";
  };

  # Custom filetype associations
  filetype = { extension = { templ = "templ"; }; };

  # Enable spell checking for text files
  autoCmd = [{
    event = [ "BufRead" "BufNewFile" ];
    pattern = [ "*.txt" "*.md" "*.tex" ];
    command = "setlocal spell";
  }];
}
