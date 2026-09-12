--- Placeholder helpers for the prompt files in this directory.
return {
  --- Diagnostics overlapping the prompt's selection, one per line.
  selection = function(args)
    local ctx = args.context
    local out = {}
    for _, d in ipairs(require("codecompanion.helpers.code").get_diagnostics(ctx.start_line, ctx.end_line, ctx.bufnr)) do
      table.insert(out, string.format("- line %d [%s] %s", d.line_number, d.severity, d.message))
    end
    if #out == 0 then
      return "(none reported)"
    end
    return table.concat(out, "\n")
  end,
}
