# ProxyGPT

ProxyGPT launches a selected macOS `.app` through a local HTTP proxy backed by
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

The six phases are:

1. Preflight and confirmation
2. Squid and restricted sshd policy
3. Dedicated Ed25519 identity
4. Runtime and tunnel smoke test
5. `ProxyGPT.app`
6. `/usr/local/bin/proxygpt` and endpoint verification

The installer intentionally has no rollback or resume mechanism. Server
configuration is staged and validated before replacement, but a later failure
does not restore earlier changes. Unhandled remote failures preserve staging
and the administrative ControlMaster for diagnostics; the idle master expires
after 300 seconds.

After installation, launch `ProxyGPT.app` in Finder or run:

```zsh
proxygpt
```

The command accepts no application or workspace arguments.

## Uninstall

Run:

```zsh
./uninstall.sh
```

The uninstaller requires the installation manifest. It offers local-only
cleanup or local cleanup plus deletion of the dedicated tunnel account and its
home directory. Shared Squid and sshd configuration are always preserved.

## Local checks

```zsh
./install-proxygpt.zsh --check
./tests/runtime-lifecycle.zsh
./tests/tunnel-phase.zsh
./tests/app-phase.zsh
./tests/integration-phase.zsh
```

These checks do not configure or contact a real server.
