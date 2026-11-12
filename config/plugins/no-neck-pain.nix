{...}: {
  plugins.no-neck-pain = {
    enable = true;
    autoLoad = true;
    settings = {
      autocmds = {
        enableOnVimEnter = true;
        skipEnteringNoNeckPainBuffer = false;
      };
    };
  };
}
