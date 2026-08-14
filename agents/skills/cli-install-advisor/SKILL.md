---
name: cli-install-advisor
description: Recommend the right installation path for CLI tools in this dotfiles repository. Use when the user asks to install, add, compare, or choose an installation method for a command-line tool, package, developer utility, language-ecosystem CLI, Homebrew formula, Nix package, mise tool, or GitHub-distributed binary in this dotfiles setup.
---

# CLI Install Advisor

## Workflow

When asked how to install a CLI in this dotfiles repo, inspect the current configuration before recommending:

- `home/packages.nix`: primary place for CLI tools managed by Home Manager.
- `hosts/darwin/default.nix`: Homebrew formulae and casks. CLI formulae here should be exceptions.
- `mise/global.toml`: runtimes, version-pinned language tools, and CLIs unsuitable for Nix.
- `flake.nix` / `flake.lock`: external flakes used when a tool is best consumed as a flake input.

Then check available candidates with current local tooling:

- Locked nixpkgs: evaluate the package from the repo flake input, for example:

  ```bash
  nix eval --raw --impure --expr 'let flake = builtins.getFlake (toString ./.); system = "aarch64-darwin"; pkgs = import flake.inputs.nixpkgs { inherit system; config.allowUnfree = true; }; in pkgs.<attr>.version'
  ```

- Homebrew: use `brew info <formula>` and, for non-core taps, verify tap trust implications.
- mise: inspect `mise/global.toml` and use mise only when the tool is a runtime, language-ecosystem CLI, needs a version pin independent of nixpkgs, or Nix is missing/broken/too old.
- Official docs or releases: use them to identify supported install methods and current upstream guidance, but do not prefer curl/manual installers for declarative dotfiles unless no managed option fits.

## Recommendation Rules

Prefer installation paths in this order:

1. `home/packages.nix` via locked nixpkgs when the package exists and the version is acceptable.
2. `mise/global.toml` when the tool is a runtime or ecosystem CLI, or when version freshness/pinning matters more than Nix integration.
3. `hosts/darwin/default.nix` Homebrew formula when Nix is missing, broken, macOS-specific, or the official Homebrew formula is materially better for this repo.
4. `flake.nix` input when the upstream project is a flake and this repo needs that exact upstream source.
5. Manual curl/download only as a last resort, and prefer wrapping it in a declarative script if it must be used.

For CLI tools, do not recommend Homebrew merely because upstream docs say `brew install`; this repo explicitly keeps CLI tools in Nix by default and reserves Homebrew for exceptions.

## Output Shape

Give the user:

- Available paths with package names and observed versions when known.
- A clear recommendation and why it matches the repo policy.
- The exact file and minimal edit that would implement it.
- Any tradeoff, such as Nix lagging Homebrew by a few releases.

If the user asks to install after the recommendation, edit the relevant file, commit the change, run `nix-rebuild`, fix failures, and push only after rebuild succeeds.

## Example

For Auth0 CLI:

- Official macOS docs recommend Homebrew (`brew tap auth0/auth0-cli && brew install auth0`).
- If locked nixpkgs provides `auth0-cli` and the version is acceptable, recommend adding `auth0-cli` to `home/packages.nix`.
- Use Homebrew only if the user needs the newer Homebrew version immediately or Nix package evaluation/build fails.
