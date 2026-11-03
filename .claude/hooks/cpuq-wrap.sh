#!/bin/bash
# PreToolUse(Bash): queue heavy JS commands (test, lint, typecheck, build) through cpuq.
# The whole command runs under `zsh -c` so &&, pipes and VAR=x prefixes keep working.
command -v cpuq >/dev/null 2>&1 || exit 0

/usr/bin/jq -c '
  .tool_input as $in
  | ($in.command // "") as $cmd
  | def heavy:
      test("^\\s*\\(?\\s*(\\w+=\\S*\\s+)*(env\\s+)?(pnpm|npm|yarn|bun|bunx|npx|turbo|vitest|jest|eslint|oxlint|tsc|tsgo)\\b")
      and test("\\b(test|tests|lint|typecheck|type-check|check-types|tsc|tsgo|build|vitest|jest|eslint|oxlint)\\b")
      and (test("--watch(?!=false)|\\s-w\\b|\\b(dev|start|serve)\\b") | not);
    if ($cmd | test("\\bcpuq\\b")) then empty
    elif ([$cmd | splits("&&|\\|\\||;|\\|") | select(heavy)] | length) == 0 then empty
    else {
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        updatedInput: ($in
          + { command: ("cpuq /bin/zsh -c " + ($cmd | @sh)) }
          + (if $in.run_in_background then {} else { timeout: ([$in.timeout // 0, 600000] | max) } end))
      }
    }
    end
'
