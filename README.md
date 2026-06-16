# Don't Stop

Don't Stop is a macOS menu bar app for keeping long-running AI coding sessions awake.

It is built for people running tools like Codex, Claude Code, Cursor, and terminal agents on a MacBook. The goal is simple: start a long task, let the Mac stay available, and stop awake mode when the work is done.

## Why

AI agents now run for longer than normal terminal commands. They may install dependencies, run tests, edit files, retry failures, or wait on slow builds. If macOS sleeps in the middle, the session can stall or fail while you are away from the keyboard.

Existing keep-awake tools are useful, but Don't Stop is focused on the agent workflow:

- keep the Mac awake while an agent runs
- show the current state in the menu bar
- support timed sessions for long tasks
- optionally keep the display awake when needed
- provide a command line helper for wrapping agent commands
- keep lid-closed behavior explicit and opt-in

## Current Status

This repo is starting with a small native macOS implementation and will grow in focused steps:

1. menu bar app
2. normal idle-sleep prevention
3. screen sleep controls
4. timers
5. opt-in lid-closed mode
6. command line helper
7. Codex and Claude setup
8. release packaging

## Terminal Helper

The helper can start or stop an awake session around a command:

```sh
./bin/dont-stop on
./bin/dont-stop status
./bin/dont-stop run -- codex
./bin/dont-stop off
```

Install it to `~/.local/bin`:

```sh
make install-helper
```

## Safety

Normal awake mode is for preventing idle system sleep while the Mac is open.

Lid-closed running is a separate opt-in mode. Use it only on a hard surface with airflow, preferably on power, and turn it off when the run is done.

Read more: [Lid Mode Safety](docs/lid-mode.md)

## Repository

Public repo:

```text
https://github.com/aannuuj/dont-stop
```
