# cpuq — queue heavy commands

If `cpuq` is on PATH, prefix every test, lint, typecheck or build command with it (`cpuq bun run test`). It queues them machine-wide so parallel agents don't saturate the CPU. Never run them in parallel. A queued command can wait minutes: set a long timeout or run it in the background.
