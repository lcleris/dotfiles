return {
  "saghen/blink.cmp",
  opts = function(_, opts)
    opts.completion = opts.completion or {}
    opts.completion.ghost_text = { enabled = false }
    opts.keymap = opts.keymap or {}
    opts.keymap["<CR>"] = {
      function(cmp)
        if cmp.accept() then
          vim.schedule(function()
            require("mini.snippets").session.stop()
          end)
          return true
        end
      end,
      "fallback",
    }
    return opts
  end,
}
