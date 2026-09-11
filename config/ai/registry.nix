# Single source of truth for AI credentials, endpoints and role->model bindings.
#
# A plain attrset, not a module: consumers `import` it at eval time so the same
# data shapes both the Nix-side plugin options and the baked `ai` Lua module.
#
# Role names match the verbs on the <leader>a keymaps, so what you press and
# what you configure line up:
#
#   ask         <leader>aa  talk about code in a chat buffer
#   edit        <leader>ae  rewrite a selection or function in place
#   agent       <leader>ad  hand a task to a CLI agent in a terminal
#   completion  ghost text / cmp candidates as you type
#   next-edit   predict the edit you are about to make, then apply it
#
# `-remote` variants are the same job against a hosted model instead of the
# local one; `-local` variants are the reverse. Only one side is ever active.
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

  endpoints = {
    ollama = "http://localhost:11434";
    opencode-go = "https://opencode.ai/zen/go";
  };

  # Defaults stay small and identical on both machines: the AMD box has no
  # discrete VRAM and the 3070 Ti has 8 GB, so anything larger spills to CPU on
  # both. NVIM_AI_TIER=big promotes the roles listed under `tiers`.
  #
  # `completion` and `next-edit` are restricted to the qwen2.5-coder models:
  # they are the only local ones advertising ollama's `insert` capability,
  # which is what real fill-in-the-middle needs.
  roles = {
    completion = {
      backend = "ollama";
      endpoint = "ollama";
      auth = "ollama";
      model = "qwen2.5-coder:1.5b-base";
    };
    # Not fill-in-the-middle: a chat model asked to guess the middle, which is
    # why it can use a model without `insert`.
    completion-remote = {
      backend = "opencode-go";
      endpoint = "opencode-go";
      auth = "opencode-go";
      model = "glm-5.3-flash";
    };
    next-edit = {
      backend = "ollama";
      endpoint = "ollama";
      auth = "ollama";
      model = "qwen2.5-coder:3b-instruct";
    };
    next-edit-remote = {
      backend = "opencode-go";
      endpoint = "opencode-go";
      auth = "opencode-go";
      model = "glm-5.3-flash";
    };
    edit = {
      backend = "ollama";
      endpoint = "ollama";
      auth = "ollama";
      model = "qwen2.5-coder:3b-instruct";
    };
    # Reached over ACP: the opencode binary supplies its own credentials, so
    # no key is needed and no local compute is spent.
    ask = {
      backend = "opencode";
      model = "openai/gpt-5.5";
    };
    ask-local = {
      backend = "ollama_ask";
      endpoint = "ollama";
      auth = "ollama";
      model = "gemma4:12b";
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
