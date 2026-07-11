# ProxyGPT

ProxyGPT-family launchers run a selected macOS `.app` through a local HTTP proxy backed by
an SSH tunnel to loopback-only Squid on a Debian or Ubuntu server. Other macOS
traffic is not reconfigured.

## Install

Run on macOS:

```zsh
./install-proxygpt.zsh
```

The installer asks for the target application, server, administrative SSH
account, tunnel account, ports, key path, and app destination. It shows a full
summary before making changes.

The selected source determines the independent output profile:

| Source | Output app | CLI |
| --- | --- | --- |
| ChatGPT | `ProxyGPT.app` | `proxygpt` |
| Codex | `ProxyCodex.app` | `proxycodex` |
| Claude | `ProxyClaude.app` | `proxyclaude` |
| Manual name/path | `ProxyLLM.app` | `proxyllm` |

Each profile has its own data directory, Ed25519 key pair, tunnel account,
random editable local-port default, control socket, app, CLI, and manifest.

The six phases are:

1. Preflight and confirmation
2. Squid and restricted sshd policy
3. Dedicated Ed25519 identity
4. Runtime and tunnel smoke test
5. Profile-specific `.app`
6. Profile-specific `/usr/local/bin/<command>` and endpoint verification

The installer intentionally has no rollback or resume mechanism. Server
configuration is staged and validated before replacement, but a later failure
does not restore earlier changes. Unhandled remote failures preserve staging
and the administrative ControlMaster for diagnostics; the idle master expires
after 300 seconds.

After installation, launch the generated app in Finder or run its CLI command,
for example:

```zsh
proxygpt
```

The command accepts no application or workspace arguments.

Source PNG files and ready-to-install macOS ICNS files are stored in
`assets/`. Each output profile uses its matching ICNS file.

## Uninstall

Run:

```zsh
./uninstall.sh
```

The uninstaller first lists profiles with a valid schema-2 manifest. It offers local-only
cleanup or local cleanup plus deletion of the dedicated tunnel account and its
home directory. Shared Squid and sshd configuration are always preserved.

## Local checks

```zsh
./install-proxygpt.zsh --check
./tests/runtime-lifecycle.zsh
./tests/tunnel-phase.zsh
./tests/app-phase.zsh
./tests/integration-phase.zsh
./tests/uninstall-local.zsh
./tests/profiles.zsh
./tests/uninstall-profile-selection.zsh
./tests/target-profile-selection.zsh
```

These checks do not configure or contact a real server.
