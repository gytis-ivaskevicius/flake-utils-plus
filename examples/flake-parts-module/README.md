# flake-parts module example

This example demonstrates how FUP's core abstractions (multi-channel management,
declarative hosts, overlay propagation, auto-registry) can be expressed as a
**composable flake-parts module**.

It is a proof-of-concept showing that the same design that makes FUP ergonomic
can work seamlessly within the flake-parts ecosystem.

## Features demonstrated

| FUP feature | flake-parts module equivalent |
|---|---|
| `channels` | `fup.channels` — declare multiple nixpkgs inputs with per-channel config and overlays |
| `sharedOverlays` | `fup.sharedOverlays` — overlays applied to every channel |
| `hosts` / `hostDefaults` | `fup.hosts` — reverse-DNS hostnames, builder dispatch (NixOS/darwin) |
| `nix.generateRegistryFromInputs` | `fup.autoRegistry` / `fup.autoNixPath` |
| `nix.generateNixPathFromInputs` | same |
| — | `fupChannels` perSystem argument for devShells/packages |

## Architectural note

FUP's `mkFlake` is monolithic — one function generates all outputs. This module
uses flake-parts' module system: options are declared, config is computed, and
modules compose. This avoids two design debts in the original:

1. **No double-eval**: FUP evaluates the entire NixOS config twice to sniff
   `nixpkgs.config`. This module evaluates nixpkgs once per (system, channel)
   pair at the flake level, cached via `channelCache`.

2. **No srcs side-channel**: FUP injects non-flake inputs into nixpkgs via an
   overlay. This module doesn't — inputs stay in their proper scope.

## Usage

```bash
nix flake show github:gytis-ivaskevicius/flake-utils-plus#examples-flake-parts-module
```

## Try it locally

```bash
cd examples/flake-parts-module
nix flake show
```
