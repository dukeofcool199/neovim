{...}: {
  plugins.no-neck-pain = {
    enable = true;
    autoLoad = true;
    settings = {
      autocmds = {
        enableOnVimEnter = true;
        skipEnteringNoNeckPainBuffer = false;
      };
      buffers = {
        scratchPad = {
          enabled = true;
          fileName = "notes";
          location = "~/notes";
        };
      };
    };
  };
}
