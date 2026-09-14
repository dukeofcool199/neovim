# AI task prompts

`prompts/` holds one markdown file per named task. They reach Neovim through
codecompanion's `prompt_library.markdown.dirs`, which is pointed at three places
(`config/plugins/codecompanion.nix`):

| directory | scope |
|---|---|
| `config/ai/prompts` | baked into the nix store, always present |
| `~/.config/codecompanion/prompts` | yours, every project |
| `.codecompanion/prompts` | one project |

A file dropped into either of the last two shows up in `<leader>at` immediately, no
rebuild. Frontmatter needs `name` and `interaction`; `opts.alias` is what
`require("ai.actions").task("<alias>")` takes.

`${conventions.block}` and `${conventions.tests}` are resolved by `prompts/conventions.lua`
against the buffer's filetype, and `${diagnostics.selection}` by `prompts/diagnostics.lua`.
Any `${name.field}` placeholder loads `name.lua` from the same directory.

## Writing a prompt a small model can follow

The default `edit` model is `qwen2.5-coder:3b-instruct`, and inline replies have to arrive
as a JSON object. Measured on that model, against samples in six languages:

- **Never list conventions for more than one language.** Shown eight, it annotates
  TypeScript with Lua's `---@param`. That is what `conventions.lua` exists to prevent.
- **Never ask it to reproduce the input.** "Return this code with documentation added"
  kept the code in 2 of 7 samples and returned *empty* in 4 — which deletes the
  selection. Prefer `placement: before` and ask only for the new lines.
- **Don't quote text you don't want echoed.** A convention reading ``` `--- Summary.` ```
  came back as a literal `--- Summary.` first line.
- **Avoid phrasing near the refusal path.** codecompanion's own system prompt offers an
  `{"error": ...}` escape, and the line "Output a complete, runnable test file... No
  prose." made the model answer `{"error": "No Lua code provided"}` with the code plainly
  in the message. Sensitivity is chaotic rather than monotonic, so verify rather than
  reason about it.
- **A task whose failure is quiet does not belong here.** Simplify collapsed definitions
  onto one line and dropped `local`, a scope change that reads as a clean diff; Add types
  emitted `function M.area(w: number)`, which is not Lua. Both were cut. Document and Fix
  survived, and the chat tasks run on the `ask` model where none of this applies.

`<leader>aT` raises the `edit` model first, for the tasks a 3B model cannot hold.

## Choosing the agent per project

`<leader>aa` opens avante, and avante has no default backend: on a fresh project it
offers a picker instead. The durable answer lives in the project's `.nvim.lua`
(Neovim's `exrc`, trusted once with `:trust`):

```lua
require("ai").setup({
  agent = { backend = "claude-code", model = "claude-sonnet-5" },
})
```

| backend | transport | model reaches it as |
|---|---|---|
| `claude-code` | ACP, `claude-agent-acp` over your own `claude` login | `ANTHROPIC_MODEL` in the agent's environment |
| `opencode` | ACP, `opencode acp` | `OPENCODE_CONFIG_CONTENT` in the agent's environment |
| `opencode-go` | HTTP, OpenCode Go with the `opencode-go` credential | per request |

`<leader>ae` (inline edit) runs on the `edit` role, not the agent: avante needs a plain
HTTP model that answers with a `<code>` block, and ACP agents answer as agents. Local
ollama by default; `edit = { backend = "opencode-go", model = "glm-5.3-flash" }` moves it.
Any other role takes the same shape, so one file can also pin `cli`.

`<leader>aq` drops the quickfix list into the agent's prompt as `- path:line:col [E] text`
lines, unsent, with the files attached to the sidebar's context; `<leader>aQ` does the
location list. Finish the instruction and submit.
`<leader>aA` makes the same choice for one session; `:AiStatus` shows what won.
Sidekick's terminals live under `<leader>k` (`kk` toggle, `kc` claude, `ki` aider, `ko`
opencode, `kP` pi, `kt`/`kv`/`kf`/`kq`/`kg` send this/selection/file/quickfix/diagnostics);
its claude tool reads the `cli` role.
