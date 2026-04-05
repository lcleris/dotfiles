return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    notify_on_error = false,

    formatters_by_ft = {
      javascript = {
        "oxfmt",
        "biome",
        "prettier",
        stop_after_first = true,
        lsp_format = "fallback",
      },
      typescript = {
        "oxfmt",
        "biome",
        "prettier",
        stop_after_first = true,
        lsp_format = "fallback",
      },
      javascriptreact = {
        "oxfmt",
        "biome",
        "prettier",
        stop_after_first = true,
        lsp_format = "fallback",
      },
      typescriptreact = {
        "oxfmt",
        "biome",
        "prettier",
        stop_after_first = true,
        lsp_format = "fallback",
      },
      json = { "biome", "prettier", stop_after_first = true, lsp_format = "fallback" },
      lua = { "stylua" },
    },

    formatters = {
      oxfmt = {
        command = require("conform.util").from_node_modules("oxfmt"),
        args = { "$FILENAME" },
        stdin = false,
        cwd = require("conform.util").root_file({ ".oxfmtrc.json", ".oxfmtrc.jsonc" }),
      },
      biome = {
        require_cwd = true,
        command = "biome",
        args = { "check", "--write", "--unsafe", "--stdin-file-path", "$FILENAME" },
        stdin = true,
      },
    },
  },
}
