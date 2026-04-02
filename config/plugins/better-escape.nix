{ ... }: {
  plugins.better-escape = {
    enable = true;
    settings = {
      timeout = 50;
      default_mappings = false;
      mappings = {
        i = {
          j = { k = "<Esc>"; l = "<Esc>"; };
          k = { j = "<Esc>"; };
          l = { j = "<Esc>"; };
        };
        s = {
          j = { k = "<Esc>"; l = "<Esc>"; };
          k = { j = "<Esc>"; };
          l = { j = "<Esc>"; };
        };
        v = {
          j = { k = "<Esc>"; l = "<Esc>"; };
          k = { j = "<Esc>"; };
          l = { j = "<Esc>"; };
        };
      };
    };
  };
}
