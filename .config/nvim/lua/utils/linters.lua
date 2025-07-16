local M = {}

local function file_exists(files)
  local cwd = vim.fn.getcwd()
  for _, file in ipairs(files) do
    if vim.fn.filereadable(cwd .. "/" .. file) == 1 or vim.fn.isdirectory(cwd .. "/" .. file) == 1 then
      return true
    end
  end
  return false
end

M.has_eslint = function()
  return file_exists({
    ".eslintrc",
    ".eslintrc.json",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    "eslint.config.js",
    "eslint.config.mjs",
  })
end

M.has_prettier = function()
  return file_exists({
    ".prettierrc",
    ".prettierrc.js",
    ".prettierrc.json",
    ".prettierrc.cjs",
    ".prettierrc.yaml",
    ".prettierrc.yml",
    "prettier.config.js",
    "prettier.config.mjs",
  })
end

M.has_biome = function()
  return file_exists({
    "biome.json",
    "biome.jsonc",
    "biome.config.json",
  })
end

return M
