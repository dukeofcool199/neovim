{ ... }:
{
  plugins.todo-comments = {
    enable = true;

    settings = {
      keywords = {
        FIX = {
          icon = "💔";
          color = "error";
          alt = [ "FIXME" "BUG" "FIXIT" "ISSUE" ];
        };
        TODO = {
          icon = "💰";
          color = "info";
        };
        HACK = {
          icon = "🌪️";
          color = "warning";
          alt = [ "HACK" "DRAGONS" ];
        };
        WARN = {
          icon = "⛈️";
          color = "warning";
          alt = [ "WARNING" "WARN" ];
        };
        PERF = {
          icon = "🐢";
          alt = [ "OPTIM" "PERFORMANCE" "OPTIMIZE" "PERF" ];
        };
        NOTE = {
          icon = "🗒️";
          color = "hint";
          alt = [ "INFO" "NOTE" ];
        };
      };
      merge_keywords = false;
      highlight = {
        pattern = ''.*(@)?(KEYWORDS)\(\s*\)\s*'';
        after = "";
      };
      search = {
        pattern = ''\b@(KEYWORDS)(\(\s*\))\s*:'';
      };
    };
  };
}
