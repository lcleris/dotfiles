local function file_exists_in_root(files)
  local root = vim.fn.getcwd()
  for _, file in ipairs(files) do
    if vim.fn.filereadable(root .. "/" .. file) == 1 or vim.fn.isdirectory(root .. "/" .. file) == 1 then
      return true
    end
  end
  return false
end

local function use_biome()
  return file_exists_in_root({ "biome.json", "biome.jsonc" })
end

local function use_eslint()
  return file_exists_in_root({
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.ts",
    ".eslintrc.json",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
  })
end

local function use_prettier()
  return file_exists_in_root({
    ".prettierrc",
    ".prettierrc.js",
    ".prettierrc.ts",
    ".prettierrc.json",
    ".prettierrc.cjs",
    ".prettierrc.yaml",
    ".prettierrc.yml",
    "prettier.config.js",
  })
end

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
      return {
        timeout_ms = 500,
        lsp_format = "fallback",
      }
    end,
    formatters_by_ft = {
      javascript = function()
        if use_biome() or (not use_eslint() and not use_prettier()) then
          return { "biome" }
        end
        local formatters = {}
        if use_eslint() then
          table.insert(formatters, "eslint_d")
        end
        if use_prettier() then
          table.insert(formatters, "prettier")
        end
        return formatters
      end,
      typescript = function()
        if use_biome() or (not use_eslint() and not use_prettier()) then
          return { "biome" }
        end
        local formatters = {}
        if use_eslint() then
          table.insert(formatters, "eslint_d")
        end
        if use_prettier() then
          table.insert(formatters, "prettier")
        end
        return formatters
      end,
      typescriptreact = function()
        if use_biome() or (not use_eslint() and not use_prettier()) then
          return { "biome" }
        end
        local formatters = {}
        if use_eslint() then
          table.insert(formatters, "eslint_d")
        end
        if use_prettier() then
          table.insert(formatters, "prettier")
        end
        return formatters
      end,
      json = { "biome" },
      css = { "biome" },
      lua = { "stylua" },
    },
  },
}
