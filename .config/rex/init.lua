-- Migrated from zellij (~/.config/zellij/config.kdl, clear-defaults=true) and Ghostty.

rex.action{
  name  = "then_normal",
  title = "Run an action and return to normal mode",
  args  = { action = "string", args = "object?" },
  run   = function(ctx, args)
    rex.client.queue(args.action, args.args or {})
    rex.client.queue("client.mode.exit_all")
  end,
}

-- zellij -----------------------------------------------------------------
-- "" is zellij's normal mode (no Rex mode). zellij's search mode is left out:
-- it is only reachable through entersearch/SearchInput, which Rex lacks.
local ALL = { "", "pane", "tab", "resize", "scroll", "session", "tmux" }

local function without(...)
  local skip, out = {}, {}
  for _, m in ipairs{ ... } do skip[m] = true end
  for _, s in ipairs(ALL) do if not skip[s] then out[#out + 1] = s end end
  return out
end

local function bind_in(scopes, key, action, args)
  for _, s in ipairs(scopes) do
    rex.bind(s == "" and key or s .. "/" .. key, action, args)
  end
end

local DIRS = { left = "left", down = "down", up = "up", right = "right",
               h = "left", j = "down", k = "up", l = "right" }

-- shared_except "locked"
for key, dir in pairs(DIRS) do
  bind_in(ALL, "alt+" .. key, "pane.focus", { direction = dir })
end
bind_in(ALL, "alt+n", "pane.split.auto")
bind_in(ALL, "ctrl+g", "client.mode.enter", { name = "locked" })

-- shared_except "locked" "renametab"
rex.bind("alt+r", "client.tab.rename")
bind_in(without(""), "alt+r", "then_normal", { action = "client.tab.rename" })

-- mode switches (shared_except "locked" "<mode>" ...)
bind_in(without("session"),       "ctrl+x", "client.mode.enter", { name = "session" })
bind_in(without("scroll"),        "ctrl+s", "client.mode.enter", { name = "scroll" })
bind_in(without("scroll", "tmux"), "ctrl+b", "client.mode.enter", { name = "tmux" })
bind_in(without("tab"),           "ctrl+t", "client.mode.enter", { name = "tab" })
bind_in(without("pane"),          "ctrl+a", "client.mode.enter", { name = "pane" })
bind_in(without("resize"),        "ctrl+n", "client.mode.enter", { name = "resize" })

-- shared_except "normal" "locked" ... : enter / esc return to normal
bind_in(without(""), "enter", "client.mode.exit_all")
bind_in(without(""), "esc",   "client.mode.exit_all")

-- locked
rex.bind("locked/ctrl+g", "client.mode.exit_all")

-- pane
rex.bind("pane/d", "then_normal", { action = "pane.split", args = { direction = "down" } })
rex.bind("pane/n", "then_normal", { action = "pane.split", args = { direction = "auto" } })
rex.bind("pane/p", "then_normal", { action = "pane.focus_next" })

-- shared_among "pane" "tmux"
for _, m in ipairs{ "pane", "tmux" } do
  for key, dir in pairs(DIRS) do
    rex.bind(m .. "/" .. key, "then_normal", { action = "pane.focus", args = { direction = dir } })
  end
  rex.bind(m .. "/x", "then_normal", { action = "pane.close" })
  rex.bind(m .. "/z", "then_normal", { action = "pane.zoom" })
end

-- tab
for key, action in pairs{ left = "previous", up = "previous", h = "previous", k = "previous",
                          down = "next", right = "next", j = "next", l = "next" } do
  rex.bind("tab/" .. key, "then_normal", { action = "client.tab." .. action })
end
for i = 1, 9 do
  rex.bind("tab/" .. i, "then_normal", { action = "client.tab.goto", args = { index = i } })
end
rex.bind("tab/b", "then_normal", { action = "pane.move_to_new_tab" })
rex.bind("tab/n", "then_normal", { action = "client.tab.new" })
rex.bind("tab/r", "then_normal", { action = "client.tab.rename" })
rex.bind("tab/x", "then_normal", { action = "client.tab.close" })
rex.bind("tab/ctrl+t", "client.mode.exit_all")

-- resize
for key, dir in pairs(DIRS) do
  rex.bind("resize/" .. key, "pane.resize", { direction = dir })
end
rex.bind("resize/ctrl+n", "client.mode.exit_all")

-- scroll
rex.bind("scroll/ctrl+s", "client.mode.exit_all")

-- session
rex.bind("session/ctrl+x", "client.mode.enter", { name = "scroll" })

-- tmux
rex.bind("tmux/shift+'", "then_normal", { action = "pane.split", args = { direction = "down" } })
rex.bind("tmux/shift+5", "then_normal", { action = "pane.split", args = { direction = "right" } })
rex.bind("tmux/,", "then_normal", { action = "client.tab.rename" })
rex.bind("tmux/[", "client.mode.enter", { name = "scroll" })
rex.bind("tmux/ctrl+b", "then_normal", { action = "pane.send_key", args = { key = "ctrl+b" } })
rex.bind("tmux/c", "then_normal", { action = "client.tab.new" })
rex.bind("tmux/n", "then_normal", { action = "client.tab.next" })
rex.bind("tmux/o", "pane.focus_next")
rex.bind("tmux/p", "then_normal", { action = "client.tab.previous" })

-- every zellij mode the user stays in
for _, m in ipairs{ "locked", "pane", "tab", "resize", "scroll", "session", "tmux" } do
  rex.mode(m, { exclusive = true })
end

-- Ghostty ----------------------------------------------------------------
rex.bind("cmd+left", "pane.focus", { direction = "left" })
rex.bind("cmd+right", "pane.focus", { direction = "right" })
rex.bind("cmd+up", "pane.focus", { direction = "up" })
rex.bind("cmd+down", "pane.focus", { direction = "down" })
rex.bind("shift+cmd+left", "client.tab.previous")
rex.bind("shift+cmd+right", "client.tab.next")
