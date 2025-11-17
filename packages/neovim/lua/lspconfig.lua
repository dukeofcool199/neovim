-- https://github.com/neovim/nvim-lspconfig
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local lsp = require("lspconfig")
local null_ls = require("null-ls")
-- local illuminate = require("illuminate")
local navic = require("nvim-navic")
local util = require("lspconfig/util")


local which_key = require("which-key")


-- @NOTE(jakehamilton): The `neodev` module requires that it is run
-- before `lspconfig` setup.
require("neodev").setup {
  lspconfig = true,
  library = {
    enabled = true,
    plugins = true,
    runtime = true,
    types = true,
  },
}

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer.
local my_on_attach = function(client, buffer)
  -- Disable formatting from duplicate providers
  -- if client.name == "ts_ls"
  --     or client.name == "html"
  --     or client.name == "cssls"
  --     or client.name == "jsonls"
  -- then
  -- end

  if client.server_capabilities.documentSymbolProvider then
    navic.attach(client, buffer)
  end

  -- illuminate.on_attach(client)

  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(buffer, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  which_key.register({
    g = {
      name = "Go",
      d = { "<cmd>lua vim.lsp.buf.definition()<cr>", "Go to definition" },
      D = { "<cmd>lua vim.lsp.buf.declaration()<cr>", "Go to declaration" },
      h = { "<cmd>lua vim.lsp.buf.hover()<cr>", "Hover" },
      i = { "<cmd>lua vim.lsp.buf.implementation()<cr>", "Go to implementation" },
      n = { "<cmd>lua require('illuminate').next_reference{wrap=true}<cr>", "Go to next occurrence" },
      p = { "<cmd>lua require('illuminate').next_reference{reverse=true,wrap=true}<cr>", "Go to previous occurrence" },
      r = { "<cmd>lua vim.lsp.buf.references()<cr>", "Go to references" },
      -- t = { "<cmd>lua vim.lsp.buf.type_definition()<cr>", "Go to type definition" },
      ["<C-k>"] = { "<cmd>lua vim.lsp.buf.signature_help()<cr>", "Signature help" }
    },
    ["["] = {
      d = { "<cmd>lua vim.diagnostic.goto_next()<cr>", "Next Diagnostic" },
    },
    ["]"] = {
      d = { "<cmd>lua vim.diagnostic.goto_prev()<cr>", "Previous Diagnostic" },
    },
  }, { buffer = buffer, mode = "n", noremap = true, silent = true })

  which_key.register({
    w = {
      name = "Workspace",
      a = { "<cmd>lua vim.lsp.buf.add_workspace_folder()<cr>", "Add workspace" },
      l = { "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>", "List workspaces" },
      r = { "<cmd>lua vim.lsp.buf.remove_workspace_folder()<cr>", "Remove workspace" },
    },
    c = {
      name = "Code",
      a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Action" },
      f = { "<cmd>lua vim.lsp.buf.format({ async = true })<cr>", "Format" },
      r = { "<cmd>lua vim.lsp.buf.rename()<cr>", "Rename" },
    }
  }, { buffer = buffer, mode = "n", prefix = "<leader>", noremap = true, silent = true })

  if client.name == "ts_ls" then
    which_key.register({
      c = {
        name = "Code",
        a = { "<cmd>lua vim.lsp.buf.code_action()<cr>", "Action" },
        f = { "<cmd>lua vim.lsp.buf.format({ async = true })<cr>", "Format" },
        r = { "<cmd>lua vim.lsp.buf.rename()<cr>", "Rename" },
        i = {
          name = "Imports",
          o = { "<cmd>OrganizeImports<cr>", "Organize" },
        },
      }
    }, { buffer = buffer, mode = "n", prefix = "<leader>", noremap = true, silent = true })
  end
end


local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Configure servers with common settings.
local servers = {
  'gopls',
  'pyright',
  'templ',
  'rust_analyzer',
  'ocamllsp',
  'gleam',
  'ols',
}




for _, name in pairs(servers) do
  lsp[name].setup {
    capabilities = capabilities,
    on_attach = my_on_attach
  }
end

lsp.rust_analyzer.setup {
  on_attach = my_on_attach,
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        allFeatures = true
      },
      procMacro = {
        enable = true
      }
    }
  }
}

lsp.dartls.setup({
  on_attach = function(client, buffer)
    my_on_attach(client, buffer)
  end,
})

lsp.zls.setup({

  on_attach = function(client, buffer)
    client.server_capabilities.documentFormattingProvider = false
    my_on_attach(client, buffer)
  end,
})


lsp.emmet_language_server.setup({
  filetypes = { "css", "vue", "eruby", "templ", "html", "htmldjango", "markdown", "javascript", "javascriptreact", "less", "sass", "scss", "pug", "typescriptreact" },
  -- Read more about this options in the [vscode docs](https://code.visualstudio.com/docs/editor/emmet#_emmet-configuration).
  -- **Note:** only the options listed in the table are supported.
  cmd = { "@emmetLanguageServer@", "--stdio" },
})


lsp.nixd.setup {
  on_attach = my_on_attach,
  formatting = {
    formatCommand = "alejandra",
    formatStdin = true,
  }
}

lsp.openscad_lsp.setup {
  on_attach = my_on_attach,
}

lsp.sqls.setup {
  on_attach = function(client)
    client.server_capabilities.documentFormattingProvider = false
  end,
}
lsp.ts_ls.setup {
  on_attach = function(client)
    client.server_capabilities.documentFormattingProvider = false
  end,
  init_options = {
    plugins = {
      {
        name = "@vue/typescript-plugin",
        location = "@vueTypescriptPlugin@",
        languages = { "vue" }
      }
    }
  },
  cmd = { "@typescriptLanguageServer@", "--stdio" },
  capabilities = capabilities,
  commands = {
    OrganizeImports = {
      function()
        vim.lsp.buf.execute_command {
          title = "Organize Imports",
          command = "_typescript.organizeImports",
          arguments = { vim.api.nvim_buf_get_name(0) },
        }
      end,
      description = "Organize Imports",
    },
  },
  filetypes = { 'typescript', 'html', "htmldjango", 'javascript', 'javascriptreact', 'typescriptreact', "vue" }
}

require('prettier').setup({
  bin = 'prettier', -- or `'prettierd'` (v0.23.3+)
})

null_ls.setup({
  sources = {
    null_ls.builtins.formatting.prettier.with({
      filetypes = { "javascript", "vue", "typescript", "typescriptreact", "javascriptreact", "html", "css", "json", "yaml" }, -- Adjust as needed
    }),
  },
})

lsp.volar.setup {
  -- on_attach = my_on_attach,
  -- filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', "vue" },
  on_attach = function(client, _)
    client.server_capabilities.documentFormattingProvider = false
  end,
  cmd = { "@volar@", "--stdio" },
  -- init_options = {
  --   typescript = { tsdk = "@typescript@/lib", },
  --   vue = {
  --     hybridMode = false
  --   }
  -- }
}


lsp.svelte.setup {
  cmd = { 'npx', 'svelteserver', '--stdio' },
  root_dir = util.root_pattern("svelte.config.js"),
  filetypes = { 'svelte' },
}
-- JSON
lsp.jsonls.setup {
  on_attach = my_on_attach,
  cmd = { "@jsonLanguageServer@", "--stdio" },
  capabilities = capabilities,
}

-- HTML
lsp.html.setup {
  on_attach = function(client, bufnr)
    my_on_attach(client, bufnr)
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
    if filetype == "markdown" then
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end
  end,
  cmd = { "@htmlLanguageServer@", "--stdio" },
  capabilities = capabilities,
  filetypes = { "html", "htmldjango", "templ", "markdown" },
}

-- use the haskell language server specific to the project
lsp.hls.setup {
  on_attach = my_on_attach,
  filetypes = { 'haskell', 'lhaskell', 'cabal' },
  capabilities = capabilities,
}

-- CSS
lsp.cssls.setup {
  on_attach = my_on_attach,
  cmd = { "@cssLanguageServer@", "--stdio" },
  capabilities = capabilities,
}

-- Docker
lsp.dockerls.setup {
  on_attach = my_on_attach,
  cmd = { "@dockerLanguageServer@", "--stdio" },
  capabilities = capabilities,
}

-- Tailwind
lsp.tailwindcss.setup {
  on_attach = my_on_attach,
  cmd = { "@tailwindLanguageServer@", "--stdio" },
  capabilities = capabilities,
  filetypes = { "templ", "astro", "javascript", "typescript", "react", "html", "typescriptreact", "vue", "svelte", "haskell" },
  init_options = { userLanguages = { templ = "html" } },
}
lsp.marksman.setup {
  on_attach = my_on_attach,
  cmd = { "@marksman@", "server" },
  capabilities = capabilities,
  filetypes = { "markdown" },
}

-- Lua
lsp.lua_ls.setup {
  on_attach = my_on_attach,
  cmd = { "lua-language-server" },
  capabilities = capabilities,
  settings = {
    Lua = {
      globals = {
        "vim",
      },
      telemetry = {
        enable = false,
      },
      format = {
        enable = true,
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
      }
    },
  },
}

-- Astro
vim.g.astro_typescript = "enable"

lsp.astro.setup {
  on_attach = my_on_attach,
  cmd = { "@astroLanguageServer@", "--stdio" },
  init_options = {
    typescript = {
      serverPath = "@typescript@",
    },
  },
}


-- Publish diagnostics from the language servers.
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  underline = true,
  update_in_insert = false,
  virtual_text = true,
  virtual_lines = { prefix = "🧨" },
  severity_sort = true,
})

-- Configure diagnostic icons.
local signs = { Error = "💥", Warn = "⚠️ ", Hint = "💡", Info = "📗" }

for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- Auto format.
vim.api.nvim_create_autocmd(
  { "BufWritePre" },
  {
    pattern = { "*" },
    callback = function()
      vim.lsp.buf.format {
        timeout = 500,
      }
    end,
  }
)

-- Disable the preview window for omnifunc use.
vim.cmd [[
	set completeopt=menu
]]
