return {
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("solarized-osaka").setup({
        styles = {
          floats = "transparent",
        },
      })
      vim.cmd([[colorscheme solarized-osaka]])
    end,
  },
  {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("colorizer").setup({
        filetypes = { "*" }, -- or restrict to { "css", "scss", "sass", "less", "javascript", "typescript", "javascriptreact", "typescriptreact" }
        user_default_options = {
          rgb = true,
          rrggbb = true,
          rgb_fn = true,
          hsl_fn = true,
          oklch = true,
          oklab = true,
          css = true,
          css_fn = true, -- enables css color() + modern funcs like oklch()
          names = false,
          mode = "background", -- or "virtualtext"
          tailwind = true,
          always_update = true,
        },
      })
    end,
  },
}
