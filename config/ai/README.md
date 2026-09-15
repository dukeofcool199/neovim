# AI task prompts

> codecompanion is not imported right now, so nothing in this section is bound
> to a key. The prompts and the guidance below survive for when it comes back.

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

## What is bound today

Sidekick's terminal agents own `<leader>a`; its `claude` tool runs the `cli`
role's model.

| key | does |
|---|---|
| `aa` | toggle the CLI split |
| `ac` `ai` `ao` `aP` | claude, aider, opencode, pi |
| `as` `ad` | select a tool, detach the session |
| `ap` | select a prompt |
| `at` `av` `af` `aq` `ag` | send this / selection / file / quickfix / diagnostics |
| `ay` | yank context (prompt-yank) |
| `am` | models and credentials (`:AiPick`, `:AiStatus`, `:AiDoctor`, `:AiAuth`, `:AiReset`) |

99 keeps its own namespace under `<leader>9` and its own two models, which it
tracks outside this registry:

| key | does |
|---|---|
| `9v` `9s` | visual replacement (edit model), project search (search model) |
| `9m` `9M` `9p` | pick the edit model, the search model, the provider |
| `9x` `9o` `9l` | stop all requests, open the last interaction, view logs |

```lua
-- .nvim.lua
require("ninetynine").set_models({
  edit   = "openai/gpt-5.6-fast",
  search = "openai/gpt-5.6-pro",
})
```

## Choosing the agent per project (avante, dormant)

avante is not imported right now — `config/plugins/avante.nix` is on disk but
out of `config/plugins/default.nix`, and the `agent` and `edit` roles go with
it. Restoring the import brings back everything below.

avante has no default backend: on a fresh project it offers a picker instead.
The durable answer lives in the project's `.nvim.lua` (Neovim's `exrc`, trusted
once with `:trust`):

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

Inline edit runs on the `edit` role, not the agent: avante needs a plain HTTP
model that answers with a `<code>` block, and ACP agents answer as agents. Local
ollama by default; `edit = { backend = "opencode-go", model = "glm-5.3-flash" }`
moves it. Any other role takes the same shape, so one file can also pin `cli` —
and that one is live today.
