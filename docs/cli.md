# CLI Reference

The `dont-stop` helper lets Terminal, Codex, Claude Code, Cursor, and scripts control the menu bar app without reimplementing macOS power behavior.

## Install

Build and install the app, then install the helper:

```sh
make install
make install-helper
```

Make sure `~/.local/bin` is on your `PATH`:

```sh
dont-stop status
```

If the app is installed somewhere else, point the helper at it:

```sh
DONT_STOP_APP="$HOME/Applications/Don't Stop.app" dont-stop status
```

## Common Commands

Start an awake session:

```sh
dont-stop on --reason codex
```

Start an awake session that stops automatically:

```sh
dont-stop on --minutes 180 --reason codex
```

Stop the current session:

```sh
dont-stop off
```

Read the current app state:

```sh
dont-stop status
```

Wrap a command so Don't Stop starts before the process and stops after it exits:

```sh
dont-stop run -- npm test
dont-stop run --reason codex -- codex
dont-stop run --reason claude -- claude
```

Keep the display awake too:

```sh
dont-stop on --display --reason demo
dont-stop run --display -- npm test
```

Allow the display to sleep while the Mac stays awake:

```sh
dont-stop run --no-display -- npm test
```

## Lid-Closed Mode

Normal CLI usage only prevents idle system sleep while the Mac is open. Use lid mode only when you explicitly need the run to continue after closing the MacBook lid.

Wrap a command with lid mode:

```sh
dont-stop run --lid --reason codex -- codex
```

Manual lid controls:

```sh
dont-stop lid on
dont-stop lid status
dont-stop lid off
```

Permission controls:

```sh
dont-stop permission status
dont-stop permission install
dont-stop permission reset
```

Use lid mode on a hard surface with airflow, preferably on power. Turn it off when the job is done.

## URL Commands

After installing the app, macOS Shortcuts and browser links can open these URLs:

```text
dont-stop://toggle
dont-stop://on
dont-stop://off
dont-stop://settings
dont-stop://lid-toggle
dont-stop://lid-on
dont-stop://lid-off
dont-stop://display-toggle
dont-stop://display-on
dont-stop://display-off
```

## Troubleshooting

If `dont-stop status` says no status has been written yet, launch the app once:

```sh
open "$HOME/Applications/Don't Stop.app"
```

If the helper cannot find the app, either run `make install` or set `DONT_STOP_APP`.

If a wrapped process was interrupted, clean up explicitly:

```sh
dont-stop off
dont-stop lid off
```

## Project Links

- Repository: <https://github.com/aannuuj/dont-stop>
- Commit history: <https://github.com/aannuuj/dont-stop/commits/master/>
