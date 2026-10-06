# Agent Launch

**Your AI terminal crew, one click away.** Agent Launch adds a compact native
Omarchy bar panel that detects the coding agents already on your `PATH`, shows
how much you have used each one over the last seven days, and opens the one
you choose in a proper terminal. It deliberately leaves your default Omarchy
agent untouched.

> **Personal project, shared as-is.** I built this for my own setup. Before
> installing, have your own coding agent review everything in this repo.

This is a **mod made by Hendrix**. Credit to **DHH and the Omarchy
contributors** for Omarchy, its plugin system, and the agent-launching
conventions this plugin builds on. Hendrix created and maintains this focused
one-click launcher.

## Supported agents

Claude Code, Codex, Cursor CLI, Grok, Hermes, OpenCode, Gemini, Muse, GitHub
Copilot, Pi, Oh My Pi, Crush, and OpenClaw—when installed on `PATH`.

## Install

```sh
omarchy plugin add https://github.com/HendrixBot/omarchy-agent-launch.git --enable
```

Click the robot (󱚣) bar button. The panel follows the layout of Omarchy's built-in
Agents panel: the selected agent's logo, name and when you last used it, a
small **Launch** button, a switch between your installed agents, and the last
seven days of usage. `h`/`l` (or ←/→) switch agents, Enter launches the
selected one, and Esc closes.

## Usage history

Usage comes from each agent's own local files and is available for:

- **Claude Code** — sessions and tokens, from `~/.claude/projects`
- **Codex** — sessions and tokens, from `~/.codex/state_5.sqlite`
- **Grok** — sessions, from `~/.grok/sessions` (Grok keeps no local token counts)

Other supported agents still get a Launch button. Token counts include input,
cache writes and output, but not cache reads. Usage history needs `python3`.

## Remove

```sh
omarchy plugin remove hippie.agent-launch
```

Removal deletes only this plugin checkout. It does not remove agent CLIs,
change your default agent, or alter agent accounts and credentials.

## Privacy

Agent Launch checks which supported commands are available on `PATH`, asks
Omarchy which agent is currently the default, and reads session metadata
(timestamps, session ids and token counts) from the local agent files listed
above. It never keeps or displays prompt or response text, never reads agent
accounts, API tokens or credentials, and sends nothing off your machine.

## License

MIT. See [LICENSE](LICENSE). Agent logos and their credits are listed in
[NOTICE.md](NOTICE.md).
