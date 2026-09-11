# Single source of truth for AI credentials, endpoints and role->model bindings.
#
# A plain attrset, not a module: consumers `import` it at eval time so the same
# data shapes both the Nix-side plugin options and the baked `ai` Lua module.
#
# Role names match the verbs on the <leader>a keymaps, so what you press and
# what you configure line up:
#
# `requires` lists what the model must be able to do, checked against
# ollama's own /api/show capabilities by :AiDoctor. "insert" is a real ollama
# capability (true fill-in-the-middle); "instruct" is derived -- a base model
# reports nothing beyond completion/insert and will not follow an instruction.
#
#   ask         <leader>aa  talk about code in a chat buffer
#   edit        <leader>ae  rewrite a selection or function in place
#   agent       <leader>ad  hand a task to a CLI agent in a terminal
#   completion  ghost text / cmp candidates as you type
#   next-edit   predict the edit you are about to make, then apply it
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

  # Geometry shared by every AI side panel, so the chat buffer and the agent
  # terminal open the same shape instead of drifting apart.
  ui.panel = {
    position = "left";
    width = 50;
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
    # codecompanion applies inline edits itself with nvim_buf_set_text, so the
    # model needs no tool-calling -- it only has to follow instructions, which
    # a base model will not.
    edit = {
      backend = "ollama";
      endpoint = "ollama";
      model = "qwen2.5-coder:3b-instruct";
      requires = ["instruct"];
    };
    # Reached over ACP: the opencode binary supplies its own credentials, so
    # no key is needed and no local compute is spent.
    ask = {
      backend = "opencode";
      model = "openai/gpt-5.5";
    };
    agent = {
      command = "claude";
      model = "claude-sonnet-5";
    };
  };

  # Opt-in overlay chosen by NVIM_AI_TIER. Unset var = the defaults above.
  tiers.big = {
    completion.model = "qwen2.5-coder:3b-base";
    edit.model = "qwen2.5-coder:3b-instruct";
  };
}
