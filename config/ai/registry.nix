# Single source of truth for AI credentials, endpoints and role->model bindings.
#
# A plain attrset, not a module: consumers `import` it at eval time so the same
# data shapes both the Nix-side plugin options and the baked `ai` Lua module.
#
# auth kinds:
#   key    - env var first, `pass` consulted only on a miss; both fields optional
#   static - literal value (ollama ignores it, but the header must exist)
#   none   - the binary authenticates itself; Neovim supplies nothing
{
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
    opencode-cli = {kind = "none";};
    claude-cli = {kind = "none";};
  };

  endpoints = {
    ollama = "http://localhost:11434";
    opencode-go = "https://opencode.ai/zen/go";
  };

  # Defaults stay small and identical on both machines: the AMD box has no
  # discrete VRAM and the 3070 Ti has 8 GB, so anything above ~8 GB spills to
  # CPU on both. NVIM_AI_TIER=big promotes the roles listed under `tiers`.
  #
  # Only the qwen2.5-coder models advertise ollama's `insert` capability, so
  # fim/duet cannot use anything else.
  roles = {
    fim = {
      auth = "ollama";
      endpoint = "ollama";
      model = "qwen2.5-coder:1.5b-base";
      kind = "fim";
    };
    fim-remote = {
      auth = "opencode-go";
      endpoint = "opencode-go";
      model = "glm-5.3-flash";
      kind = "chat";
    };
    duet = {
      auth = "ollama";
      endpoint = "ollama";
      model = "qwen2.5-coder:3b-instruct";
      kind = "chat";
    };
    duet-remote = {
      auth = "opencode-go";
      endpoint = "opencode-go";
      model = "glm-5.3-flash";
      kind = "chat";
    };
    inline = {
      auth = "ollama";
      endpoint = "ollama";
      model = "qwen2.5-coder:3b-instruct";
      adapter = "ollama";
      kind = "chat";
    };
    chat = {
      acp = "opencode";
      adapter = "opencode";
      model = "openai/gpt-5.5";
      kind = "acp";
    };
    chat-local = {
      auth = "ollama";
      endpoint = "ollama";
      model = "gemma4:12b";
      adapter = "ollama";
      kind = "chat";
    };
    agent = {
      cli = "claude";
      model = "claude-sonnet-5";
      kind = "cli";
    };
  };

  # Opt-in overlay chosen by NVIM_AI_TIER. Unset var = the defaults above.
  tiers.big = {
    fim.model = "qwen2.5-coder:3b-base";
    inline.model = "qwen2.5-coder:3b-instruct";
  };
}
