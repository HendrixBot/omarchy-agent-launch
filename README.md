# Agent Launch

**Your AI terminal crew, one click away.** Agent Launch adds a compact native
Omarchy bar panel that detects the coding agents already on your `PATH`, then
opens the one you choose in a proper terminal. It deliberately leaves your
default Omarchy agent untouched.

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

Click the `AI` bar button, select an installed agent, and it opens in a
terminal. `j`/`k` navigate, Enter launches, and Esc closes.

## Remove

```sh
omarchy plugin remove hippie.agent-launch
```

Removal deletes only this plugin checkout. It does not remove agent CLIs,
change your default agent, or alter agent accounts and credentials.

## Privacy

Agent Launch only checks which supported commands are available on `PATH` and
asks Omarchy which agent is currently the default. It does not read or publish
prompts, project files, agent accounts, tokens, or credentials.

## License

MIT. See [LICENSE](LICENSE).
