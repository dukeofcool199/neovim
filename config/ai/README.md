# AI task prompts

> In-editor reference: `:help ai-registry`. Roles, the resolution layers,
> `.nvim.lua` recipes, every `:Ai*` command and the keymaps live there.

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

These tasks ran on a local `qwen2.5-coder:3b-instruct`, and inline replies have to arrive
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

`<leader>aT` raised the model first, for the tasks a 3B model cannot hold.

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

99 keeps its namespace under `<leader>9`, but its two models are the `edit` and
`search` roles, so everything that reaches a role reaches 99:

| key | does |
|---|---|
| `9v` `9s` | rewrite the selection (`edit`), search the project (`search`) |
| `9m` `9M` | pick the agent and model for `edit`, for `search` |
| `9x` `9o` `9l` | stop all requests, open the last interaction, view logs |

```lua
-- .nvim.lua
require("ai").setup({
  edit   = {model = "openai/gpt-5.6-fast"},
  search = {backend = "claude-code", model = "claude-opus-5"},
})
```

`require("ninetynine")` is gone; a project file that still calls it will error.

Both roles must sit on an agent that names a `provider` in the registry —
`opencode` or `claude-code`. They are not equivalent: opencode is spawned with a
permission set denying every edit outside 99's tmp file, plus bash and task,
while claude-code runs `--dangerously-skip-permissions` with no fence. opencode
is the default on both roles for that reason.

`9m` lists every model across every agent, each row naming its own, so picking a
claude row moves the role onto claude in the same keypress:

```
claude-code  claude-opus-5
claude-code  claude-sonnet-5
opencode     openai/gpt-5.5
opencode     openai/gpt-5.6-fast
```

The claude rows come from the registry rather than 99's own list, which is a
generation stale — the claude CLI cannot enumerate models, so someone has to
hold the list and the registry already does. Use `:AiBackend <role> <backend>`
to move a role without touching its model.

## Choosing the agent per project (avante, dormant)

avante is not imported right now — `config/plugins/avante.nix` is on disk but
out of `config/plugins/default.nix`, and the `agent` role goes with it.
Restoring the import brings back everything below.

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

avante's inline edit cannot share the `edit` role any more: it needs a plain
HTTP model that answers with a `<code>` block, and `edit` now drives a CLI agent
for 99. Restoring avante means either pointing `edit` back at an HTTP backend
(`{ backend = "opencode-go", model = "glm-5.3-flash" }`) and giving 99 a role of
its own, or giving avante one. Any role takes the same `.nvim.lua` shape, so one
file can also pin `cli` — and that one is live today.
