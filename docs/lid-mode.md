# Lid Mode Safety

Don't Stop has two different power behaviors:

- Normal awake mode keeps the Mac from idle sleeping while it is open.
- Lid mode is an opt-in mode for controlled closed-lid runs.

Normal awake mode is the default. Use it for most long Codex, Claude Code, Cursor, or terminal-agent sessions.

## When To Use Lid Mode

Use lid mode only when a long-running task needs to continue after the MacBook lid closes.

Good conditions:

- the Mac is on a hard surface
- airflow is not blocked
- power is connected when possible
- the task has a clear end
- you plan to turn lid mode off when the run is done

Avoid lid mode when the Mac is in a bag, under bedding, on a soft surface, or anywhere heat can build up.

## What To Expect

When lid mode is enabled, Don't Stop asks for confirmation first. macOS may also ask for administrator permission before changing system power behavior.

When lid mode is disabled, Don't Stop restores normal closed-lid sleep behavior.

## Practical Guidance

- Prefer normal awake mode unless you need closed-lid running.
- Use a timer for long tasks when possible.
- Check the Mac after enabling lid mode for the first time.
- Turn lid mode off when the agent run is finished.
