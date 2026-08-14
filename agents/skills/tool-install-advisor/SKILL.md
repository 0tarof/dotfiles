---
name: tool-install-advisor
description: Recommend the right installation path for tools in this dotfiles repository. Use when the user asks to install, add, compare, or choose an installation method for a command-line tool, GUI app, developer utility, language runtime, language-ecosystem package, Homebrew formula or cask, Nix package, mise tool, GitHub-distributed binary, or external flake in this dotfiles setup.
---

# Tool Install Advisor

## Workflow

When asked how to install a tool in this dotfiles repo, inspect the current configuration before recommending:

- `.local/nix/config.nix` or the `NIX_SYSTEM` / `NIX_USERNAME` / `NIX_HOSTNAME` environment variables: identify whether the target is Darwin or Linux/WSL.
- `home/packages.nix`: primary place for CLI tools and developer packages managed by Home Manager.
- `hosts/darwin/default.nix`: Darwin-only Homebrew formula exceptions and GUI casks managed by nix-darwin.
- `mise/global.toml`: language runtimes, ecosystem tools, and CLIs that need independent version pins or are unsuitable for Nix.
- `flake.nix` / `flake.lock`: external flakes used when a tool is best consumed from upstream flake outputs.
- `overlay/nix/home.nix`: machine-specific Home Manager additions when the tool should not be global.

The flake has two activation targets:

- Darwin: `darwinConfigurations.${hostname}`, using nix-darwin plus Home Manager.
- Linux/WSL: `homeConfigurations."${username}@${hostname}"`, using standalone Home Manager. There is no shared `hosts/linux` module in the current repo.

Then check available candidates with current local tooling:

- Locked nixpkgs: evaluate the package from the repo flake input for the relevant system, for example:

  ```bash
  nix eval --raw --impure --expr 'let flake = builtins.getFlake (toString ./.); system = "aarch64-darwin"; pkgs = import flake.inputs.nixpkgs { inherit system; config.allowUnfree = true; }; in pkgs.<attr>.version'
  ```

- Homebrew: use `brew info <formula-or-cask>` and, for non-core taps, verify tap trust implications.
- mise: inspect `mise/global.toml` and use mise only when the tool is a runtime, language-ecosystem tool, needs a version pin independent of nixpkgs, or Nix is missing/broken/too old.
- Official docs or releases: use them to identify supported install methods and current upstream guidance, but do not prefer curl/manual installers for declarative dotfiles unless no managed option fits.

## Recommendation Rules

Prefer installation paths by tool type:

1. CLI/developer packages: use `home/packages.nix` via locked nixpkgs when the package exists and the version is acceptable.
2. Darwin GUI apps: use `hosts/darwin/default.nix` Homebrew casks.
3. Language runtimes and ecosystem tools: use `mise/global.toml` when freshness, exact version pinning, or ecosystem semantics matter more than Nix integration.
4. Darwin Homebrew formulae: use `hosts/darwin/default.nix` only when Nix is missing, broken, macOS-specific, or materially worse for this repo.
5. External flakes: use `flake.nix` when upstream provides a flake and this repo needs that exact source or package output.
6. Linux GUI or desktop tools: prefer Nix/Home Manager when practical; otherwise explain that this repo has no declarative Flatpak/AppImage/distro-package management yet and ask before adding a new mechanism.
7. Manual curl/download: use only as a last resort, and prefer wrapping it in a declarative activation script if it must be used.

Do not recommend Homebrew merely because upstream docs say `brew install`; this repo keeps command-line tools in Nix by default and reserves Homebrew formulae for exceptions. Conversely, do not force GUI apps into Nix when this repo already manages GUI apps as Homebrew casks.

On Linux/WSL, do not recommend `hosts/darwin/default.nix` or Homebrew casks. Homebrew/Linuxbrew may appear in shell PATH handling, but it is not a primary declarative install mechanism in the current repo.

## Output Shape

Give the user:

- The assumed target OS/configuration and whether it came from local config or inference.
- Available paths with package names and observed versions when known.
- A clear recommendation and why it matches the repo policy.
- The exact file and minimal edit that would implement it.
- Any tradeoff, such as Nix lagging Homebrew by a few releases.

Stop after recommending unless the user explicitly asks to implement. If the user asks to install after the recommendation, edit the relevant file, commit the change, run `nix-rebuild`, fix failures, and push only after rebuild succeeds.

## Examples

For Auth0 CLI:

- Official macOS docs recommend Homebrew (`brew tap auth0/auth0-cli && brew install auth0`).
- If locked nixpkgs provides `auth0-cli` and the version is acceptable, recommend adding `auth0-cli` to `home/packages.nix`.
- Use Homebrew only if the user needs the newer Homebrew version immediately or Nix package evaluation/build fails.

For a GUI editor:

- Check whether this repo already manages similar apps in `hosts/darwin/default.nix`.
- Recommend a Homebrew cask when the target is Darwin and the app is a GUI macOS application.
- For Linux/WSL, avoid the Darwin cask path and prefer Nix/Home Manager when practical.
