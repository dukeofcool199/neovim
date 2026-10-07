{...}: {
  plugins.image = {
    enable = true;
    settings = {
      processor = "magick_rock";
      integrations = {
        markdown.enabled = true;
        typst.enabled = true;
        neorg.enabled = true;
        syslang.enabled = true;
        html.enabled = true;
        css.enabled = true;
      };
    };
  };
}
