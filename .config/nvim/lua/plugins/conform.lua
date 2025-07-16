local linters = require("utils.linters")

return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  opts = {
    notify_on_error = false,

    format_on_save = function(bufnr)
      local disable_filetypes = { c = true, cpp = true }
      if disable_filetypes[vim.bo[bufnr].filetype] then
        return nil
      end
      return { timeout_ms = 500, lsp_format = "fallback" }
    end,

    formatters_by_ft = {
      javascript = { "project_linter" },
      javascriptreact = { "project_linter" },
      typescript = { "project_linter" },
      typescriptreact = { "project_linter" },
      json = { "project_linter" },
      css = { "project_linter" },
      lua = { "stylua" },
    },

    formatters = {
      project_linter = {
        command = function()
          if linters.has_eslint() then
            return "eslint_d"
          end
          if linters.has_prettier() then
            return "prettier"
          end
          return "biome"
        end,
      },
    },
  },
}
