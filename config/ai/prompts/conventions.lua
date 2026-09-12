--- Language conventions, each resolved to the one language in play.
---
--- A small model shown a dozen conventions at once mixes them: TypeScript comes back
--- annotated with Lua's `---@param`. The prompt files interpolate `${conventions.block}`
--- and `${conventions.tests}` so the model only ever sees the one that applies.
local BY_FILETYPE = {
  lua = "LuaCATS comments. A first line of prose, then one `---@param name type` for each parameter, then `---@return type`. Every line begins with three dashes. Leave off a trailing description when the name and type already carry it.",
  python = "`#` comments of prose. Python normally puts a `\"\"\"` string inside the body, but this block lands above the `def`, so use `#` and do not emit a string literal.",
  rust = "`///` comments, one line per sentence. Use `# Panics` and `# Errors` sections only when either applies.",
  go = "`//` comments, as a complete sentence beginning with the identifier being documented.",
  javascript = "a `/** ... */` block of prose. Add `@param` and `@returns` only when there is more to say than the names already carry. Your answer ends at the closing `*/`.",
  typescript = "a `/** ... */` block of prose. The types are in the signature already, so add `@param` and `@returns` only when there is something the type does not say. Your answer ends at the closing `*/`.",
  haskell = "`-- |` for the block, with `-- ^` on an argument only when it needs it.",
  ruby = "`#` comments above the definition.",
  sh = "`#` comments above the definition.",
  nix = "`#` comments above the definition.",
  c = "a `/** ... */` block with `@param` and `@return`.",
  java = "a `/** ... */` Javadoc block with `@param` and `@return`.",
  elixir = "`#` comments. Elixir normally uses `@doc` inside the module, but this block lands above the definition, so use `#`.",
}

local TESTS_BY_FILETYPE = {
  lua = "busted: `describe` and `it` blocks, with `assert.are.same` and `assert.has_error`.",
  python = "pytest: plain `test_` functions, `assert`, and `pytest.raises` for errors.",
  typescript = "vitest: `describe` and `it`, with `expect(...).toBe` and `expect(() => ...).toThrow`.",
  javascript = "vitest: `describe` and `it`, with `expect(...).toBe` and `expect(() => ...).toThrow`.",
  rust = "a `#[cfg(test)] mod tests` block of `#[test]` functions using `assert_eq!`.",
  go = "the `testing` package: `func TestName(t *testing.T)` with table-driven subtests via `t.Run`.",
  haskell = "hspec: `describe` and `it` with `shouldBe`.",
  ruby = "RSpec: `describe` and `it` with `expect(...).to eq`.",
  java = "JUnit 5: `@Test` methods with `assertEquals` and `assertThrows`.",
  elixir = "ExUnit: `describe` and `test` with `assert`.",
}

local ALIASES = {
  javascriptreact = "javascript",
  typescriptreact = "typescript",
  bash = "sh",
  zsh = "sh",
  cpp = "c",
  objc = "c",
  kotlin = "java",
  scala = "java",
}

local function lookup(table_, args, fallback)
  local ft = args.context.filetype or ""
  return table_[ALIASES[ft] or ft] or fallback(ft ~= "" and ft or "this language")
end

return {
  --- The documentation form for the buffer's language, phrased to follow "Use".
  block = function(args)
    return lookup(BY_FILETYPE, args, function(ft)
      return "the form " .. ft .. " uses for documentation above a definition."
    end)
  end,

  --- The test framework for the buffer's language, phrased to follow "Use".
  tests = function(args)
    return lookup(TESTS_BY_FILETYPE, args, function(ft)
      return "the test framework " .. ft .. " projects conventionally reach for."
    end)
  end,
}
