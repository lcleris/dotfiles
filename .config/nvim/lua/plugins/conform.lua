return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    notify_on_error = false,

    formatters_by_ft = {
      javascript = {
        "biome",
        "prettier",
        stop_after_first = true,
        lsp_format = "fallback",
      },
      typescript = {
        "biome",
        "prettier",
        stop_after_first = true,
        lsp_format = "fallback",
      },
      javascriptreact = {
        "biome",
        "prettier",
        stop_after_first = true,
        lsp_format = "fallback",
      },
      typescriptreact = {
        "biome",
        "prettier",
        stop_after_first = true,
        lsp_format = "fallback",
      },
      json = { "biome", "prettier", stop_after_first = true, lsp_format = "fallback" },
      lua = { "stylua" },
    },

    formatters = {
      biome = {
        require_cwd = true,
        command = "biome",
        args = { "check", "--write", "--unsafe", "--stdin-file-path", "$FILENAME" },
        stdin = true,
      },
    },
  },
}
