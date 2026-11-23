# cpuq — queue heavy commands

Prefix every test, lint, typecheck or build command with `cpuq` (`cpuq bun run test`). It waits for free CPU and memory before starting, so a command can wait minutes: set a long timeout.
