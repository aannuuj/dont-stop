# Add Don't Stop To Codex Or Claude

Don't Stop includes a CLI helper and a small agent skill so Codex or Claude can keep long-running Mac tasks awake while they work.

## Install The CLI Helper

Install the menu bar app and the `dont-stop` terminal helper first:

```bash
make install
make install-helper
```

Confirm the helper is available:

```bash
dont-stop status
```

## Codex

Install the skill into the shared agent skills folder:

```bash
make install-codex-skill
```

Or copy it manually:

```bash
mkdir -p ~/.agents/skills
cp -R .agents/skills/dont-stop ~/.agents/skills/dont-stop
```

Then ask Codex to use the `dont-stop` skill when a run should stay awake:

```text
Use the dont-stop skill and keep this build running until tests finish.
```

For direct CLI use, wrap the Codex command:

```bash
dont-stop run --reason codex -- codex
```

## Claude Code

Install the same skill into Claude's skills folder:

```bash
make install-claude-skill
```

Or copy it manually:

```bash
mkdir -p ~/.claude/skills
cp -R .agents/skills/dont-stop ~/.claude/skills/dont-stop
```

Then ask Claude to use the skill before long work:

```text
Use the dont-stop skill while you run this migration and test suite.
```

For direct CLI use, wrap the Claude command:

```bash
dont-stop run --reason claude -- claude
```

## What The Skill Does

- Starts an awake session before a long task through the `dont-stop` CLI.
- Checks whether Don't Stop is currently active.
- Stops the session when the protected work is done.
- Uses lid-closed mode only when you explicitly ask for it.

## Recommended Prompt

```text
Use Don't Stop while this task runs. Keep the Mac awake, avoid lid mode unless I explicitly ask for it, and release the awake session when the command finishes.
```
