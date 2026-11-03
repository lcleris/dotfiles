# pstack model configuration. One line per role. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent chat model (omit Agent `model`). Alias entries in a panel list still count toward its fan-out.
# budget: custom — judgment follows the orchestrator session (opus high, raised per task); code on sonnet; search on haiku
feature, refactoring: sonnet high
bug-fix: sonnet high
perf-issue: sonnet high
hillclimb: sonnet high
judgment and prose: inherit-parent
hardest tasks: inherit-parent
how explorer: haiku high
how explainer: inherit-parent
why investigators: sonnet high
why synthesizer: inherit-parent
reflect tooling: haiku high
reflect judgment, divergent, synthesizer: inherit-parent
arena runners: inherit-parent, sonnet high
arena cross-judge pool: inherit-parent, sonnet high
swarm workers: sonnet high
architect runners: inherit-parent, sonnet high
interrogate reviewers: inherit-parent, sonnet high
