# Single source of truth for AI credentials, endpoints and role->model bindings.
#
# A plain attrset, not a module: consumers `import` it at eval time so the same
# data shapes both the Nix-side plugin options and the baked `ai` Lua module.
#
# Role names match the verbs on the keymaps, so what you press and what you
# configure line up:
#
# `requires` lists what the model must be able to do, checked against
# ollama's own /api/show capabilities by :AiDoctor. "insert" is a real ollama
# capability (true fill-in-the-middle); "instruct" is derived -- a base model
# reports nothing beyond completion/insert and will not follow an instruction.
# Only an ollama role can be checked, so only an ollama role carries it.
#
#   edit        <leader>9v  99 rewrites the selection through a CLI agent
#   search      <leader>9s  99 searches the project through a CLI agent
#   cli         <leader>a*  sidekick's terminal agents; `claude` runs this model
#
# Set aside -- still configured here, their plugin files just aren't imported:
#   agent       avante's agentic sidebar (avante.nix)
#   ask         a codecompanion chat buffer (codecompanion.nix)
#   completion  minuet ghost text / cmp candidates as you type (minuet.nix)
#   next-edit   minuet duet: predict the edit you are about to make (minuet.nix)
#
{
  # kind = "key"    -> env var first, `pass` consulted only on a miss
  # kind = "static" -> literal value (ollama ignores it, but the header must exist)
  # kind = "none"   -> the binary authenticates itself; Neovim supplies nothing
  auth = {
    ollama = {
      kind = "static";
      value = "ollama";
    };
    opencode-go = {
      kind = "key";
      env = "OPENCODE_API_KEY";
      pass = "ai/opencode-go";
    };
    anthropic = {
      kind = "key";
      env = "ANTHROPIC_API_KEY";
      pass = "ai/anthropic";
    };
    openrouter = {
      kind = "key";
      env = "OPENROUTER_API_KEY";
      pass = "ai/openrouter";
    };
    # The `opencode` and `claude` binaries hold their own credentials.
    opencode-cli = {kind = "none";};
    claude-cli = {kind = "none";};
  };

  # Geometry shared by every AI side panel, so the agent terminal and any
  # chat buffer open the same shape instead of drifting apart.
  ui.panel = {
    position = "left";
    width = 50;
  };

  # The agent terminals float over the editor instead of splitting it, so a
  # full-screen oversight.nvim review stays laid out underneath and the CLI
  # toggles in and out on top of it. Fractions are of the editor; sidekick
  # floors a float at 80x10.
  ui.overlay = {
    width = 0.85;
    height = 0.85;
  };

  # Each endpoint owns its credential, so pointing a role at a different
  # endpoint carries the right auth with it -- no per-role auth field to keep
  # in sync.
  endpoints = {
    ollama = {
      url = "http://localhost:11434";
      auth = "ollama";
    };
    opencode-go = {
      url = "https://opencode.ai/zen/go";
      auth = "opencode-go";
    };
  };

  # Defaults stay small and identical on both machines: the AMD box has no
  # discrete VRAM and the 3070 Ti has 8 GB, so anything larger spills to CPU on
  # both. NVIM_AI_TIER=big promotes the roles listed under `tiers`.
  #
  # `completion` and `next-edit` are restricted to the qwen2.5-coder models:
  # they are the only local ones advertising ollama's `insert` capability,
  # which is what real fill-in-the-middle needs.
  # A role is a job, not a place. Point one at a local endpoint or a hosted
  # one by setting its backend and model -- there is no separate "remote"
  # role to switch to.
  #
  # `requires` is checked against ollama's /api/show by :AiDoctor. "insert" is
  # a real ollama capability (true fill-in-the-middle); "instruct" is derived,
  # since a base model reports nothing beyond completion/insert.
  roles = {
    completion = {
      backend = "ollama";
      endpoint = "ollama";
      model = "qwen2.5-coder:1.5b-base";
      requires = ["insert"];
    };
    next-edit = {
      backend = "ollama";
      endpoint = "ollama";
      model = "qwen2.5-coder:3b-instruct";
      requires = ["instruct"];
    };
    # 99's two roles. Both drive a CLI agent, so the backend must be one of
    # `agents` below that names a `provider`.
    edit = {
      backend = "opencode";
      model = "openai/gpt-5.5";
    };
    search = {
      backend = "opencode";
      model = "openai/gpt-5.5";
    };
    # Reached over ACP: the opencode binary supplies its own credentials, so
    # no key is needed and no local compute is spent.
    ask = {
      backend = "opencode";
      model = "openai/gpt-5.5";
    };
    # Dormant with avante, and no default on purpose: a project named its
    # backend (one of `agents` below) and model in .nvim.lua:
    #   require("ai").setup({agent = {backend = "claude-code", model = "claude-sonnet-5"}})
    agent = {};
    cli = {
      command = "claude";
      model = "claude-sonnet-5";
    };
  };

  # The CLI agents a role can be pointed at. Each holds its own credentials,
  # and the model reaches it through the environment it is spawned with (claude
  # reads ANTHROPIC_MODEL, opencode reads OPENCODE_CONFIG_CONTENT). An HTTP
  # backend names an endpoint above and carries that endpoint's credential.
  #
  # `models` is what the picker offers: a list when the agent cannot enumerate
  # them itself (claude has no models command), or a provider prefix to narrow
  # `opencode models`. An agent naming an `endpoint` needs neither -- its list
  # is that endpoint's /v1/models, fetched live.
  #
  # `provider` names the key in `_99.Providers`, and its absence means 99
  # cannot reach this agent. `command` is the binary 99 spawns for it, which is
  # how two agents share one provider: claude-code and claude-go are both
  # ClaudeCodeProvider, differing only in which claude they run.
  #
  # All three fence 99's agent, by their own route: opencode by a permission
  # set denying every edit outside the tmp file plus bash and task, the claude
  # pair by a --settings allow-list with --permission-prompts none.
  agents = {
    claude-code = {
      transport = "acp";
      command = "claude";
      provider = "ClaudeCodeProvider";
      models = ["claude-sonnet-5" "claude-opus-5" "claude-fable-5-1" "claude-haiku-4-5-20251001"];
    };
    # The same claude CLI pointed at OpenCode Go: the wrapper in
    # config/ai/default.nix supplies the base URL, the `opencode-go`
    # credential and the session header the gateway requires. Nothing claude-*
    # runs on it -- go serves no Anthropic models.
    #
    # The list is here rather than left to the endpoint because go's
    # /v1/models answers with all 42 ids while only these speak the Anthropic
    # protocol; the rest answer /v1/messages with ModelProtocolUnsupported and
    # would be rows in the picker that cannot work. Re-derive it by POSTing a
    # one-token message to /v1/messages for each id the endpoint lists.
    claude-go = {
      transport = "acp";
      command = "claude-go";
      provider = "ClaudeCodeProvider";
      endpoint = "opencode-go";
      models = [
        "minimax-m3"
        "minimax-m2.7"
        "minimax-m2.5"
        "kimi-k3"
        "qwen3.8-max"
        "qwen3.8-flash"
        "qwen3.7-max"
        "qwen3.7-plus"
        "qwen3.6-plus"
        "deepseek-v4-flash-vision-exp"
        "space-bunny-free"
      ];
    };
    opencode = {
      transport = "acp";
      command = "opencode";
      provider = "OpenCodeProvider";
    };
    opencode-go = {
      transport = "http";
      endpoint = "opencode-go";
    };
  };

  # Opt-in overlay chosen by NVIM_AI_TIER. Unset var = the defaults above.
  # Only the ollama roles appear: a tier is about local VRAM, and a role that
  # shells out to an agent spends none.
  tiers.big = {
    completion.model = "qwen2.5-coder:3b-base";
  };
}
