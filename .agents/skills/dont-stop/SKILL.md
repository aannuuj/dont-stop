---
name: dont-stop
description: Use when a user wants Codex, Claude Code, Cursor, terminal commands, build jobs, tests, or other long-running Mac tasks to keep running without idle sleep. Helps start, stop, wrap, and check the Don't Stop macOS helper, including lid-closed mode only when explicitly requested.
---

# Don't Stop

Use the Don't Stop macOS helper to keep long-running agent work alive on a Mac. Prefer the helper over direct `pmset` or `caffeinate` calls because it coordinates with the menu bar app, writes state, and cleans up wrapped sessions.

## Locate the Helper

Resolve the command in this order:

1. `dont-stop` from `PATH`
2. `./bin/dont-stop` from the current repo
3. `DONT_STOP_APP="/Applications/Don't Stop.app" ./bin/dont-stop` when the helper exists but the app is installed in `/Applications`
4. Ask the user to install the app/helper if none of the above exists

Before using it for a long run, a quick status check is useful:

```sh
dont-stop status
dont-stop lid status
dont-stop permission status
```

## Default Behavior

For any long-running command where the user wants the Mac to stay awake, wrap the command:

```sh
dont-stop run --reason codex -- COMMAND [ARGS...]
```

Examples:

```sh
dont-stop run --reason codex -- codex
dont-stop run --reason claude -- claude
dont-stop run --reason tests -- npm test
```

The wrapper turns awake mode on before the process starts and turns it off when the process exits.

## Lid-Closed Mode

Only enable lid-closed running when the user explicitly asks for lid-closed, clamshell, close-lid, overnight, or similar behavior. This changes a global macOS power setting and has heat/battery risk.

On Apple Silicon, lid-close sleep is partly hardware-gated. Reliability is best on power, with airflow, and even better with an external display.

Use:

```sh
dont-stop run --lid --reason codex -- COMMAND [ARGS...]
```

For manual control:

```sh
dont-stop lid on
dont-stop lid off
```

The helper installs one scoped sudoers rule on first lid use, then switches with `sudo -n` for exactly:

```sh
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

Warn briefly before enabling lid mode: keep the Mac on power or with sufficient battery, on a hard surface, with airflow.

## Display Policy

Do not keep the display on unless the user asks. When needed:

```sh
dont-stop run --display --reason demo -- COMMAND [ARGS...]
dont-stop on --display --reason demo
```

To allow display sleep while keeping the system awake:

```sh
dont-stop run --no-display --reason codex -- COMMAND [ARGS...]
```

## Timed Awake Sessions

For manual sessions that should auto-expire:

```sh
dont-stop on --minutes 180 --reason codex
```

Turn it off explicitly when the work is done:

```sh
dont-stop off
```

## Recovery

If a run was interrupted, check and clean up:

```sh
dont-stop status
dont-stop off
dont-stop lid status
dont-stop lid off
dont-stop permission status
```

If the app cannot be found, suggest one of:

```sh
make build
make install
make install-helper
```

Do not install or edit sudoers directly from the skill. Let the app/helper handle scoped permission setup unless the user specifically asks for manual system changes.

If the user asks to remove the no-password permission:

```sh
dont-stop permission reset
```
