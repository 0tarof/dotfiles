# ==========================================================================
# External agent skills - pinned Git sources projected into agent skill dirs
# ==========================================================================
{ config, lib, pkgs, ... }:

let
  manifest = builtins.fromTOML (builtins.readFile ../agent-skills.toml);
  supportedTargets = [ "agents" "claude" ];
  skillNames = map (skill: skill.name) config.agentSkills.skills;

  validateSkill = skill:
    assert builtins.match "^[A-Za-z0-9._-]+$" skill.name != null;
    assert skill.name != "." && skill.name != "..";
    assert !(lib.hasPrefix "/" skill.path) && !(lib.hasInfix ".." skill.path);
    assert lib.all (target: builtins.elem target supportedTargets) skill.targets;
    assert builtins.match "^[0-9a-f]{40}$" skill.rev != null;
    skill;

  skills =
    assert lib.assertMsg (lib.length skillNames == lib.length (lib.unique skillNames))
      "agentSkills: duplicate skill names: ${lib.concatStringsSep ", " skillNames}";
    map validateSkill config.agentSkills.skills;

  syncCommands = lib.concatMapStringsSep "\n" (skill:
    lib.concatMapStringsSep "\n" (target: ''
      run_sync \
        ${lib.boolToString skill.optional} \
        ${lib.escapeShellArg skill.name} \
        ${lib.escapeShellArg skill.repository} \
        ${lib.escapeShellArg skill.ref} \
        ${lib.escapeShellArg skill.rev} \
        ${lib.escapeShellArg skill.path} \
        ${lib.escapeShellArg target}
    '') skill.targets
  ) skills;

  agentSkillsSync = pkgs.writeShellApplication {
    name = "agent-skills-sync";
    runtimeInputs = [ pkgs.git pkgs.openssh pkgs.coreutils pkgs.gnugrep ];
    text = ''
      set -euo pipefail

      force=false
      if [[ "''${1:-}" == "--force" ]]; then
        force=true
        shift
      fi
      if [[ $# -ne 0 ]]; then
        echo "usage: agent-skills-sync [--force]" >&2
        exit 2
      fi

      cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/agent-skills"
      state_root="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/agent-skills"
      managed_state="$state_root/managed-targets"
      desired_state="$state_root/managed-targets.next.$$"
      mkdir -p "$cache_root" "$state_root"
      : > "$desired_state"
      trap 'rm -f "$desired_state"' EXIT

      target_root_for() {
        case "$1" in
          agents) printf '%s\n' "$HOME/.agents/skills" ;;
          claude) printf '%s\n' "$HOME/.claude/skills" ;;
          *) echo "unknown agent skill target: $1" >&2; return 2 ;;
        esac
      }

      sync_skill() {
        local name="$1"
        local repository="$2"
        local ref="$3"
        local rev="$4"
        local skill_path="$5"
        local target_kind="$6"
        local cache_dir="$cache_root/$name"
        local marker="$cache_dir/.dotfiles-source"
        local expected_marker="$repository#$ref@$rev"
        local target_root
        local target

        target_root="$(target_root_for "$target_kind")"
        target="$target_root/$name"
        printf '%s\n' "$target" >> "$desired_state"

        if [[ "$force" == true || ! -f "$marker" || "$(<"$marker")" != "$expected_marker" || ! -f "$cache_dir/$skill_path/SKILL.md" ]]; then
          local temporary
          temporary="$(mktemp -d "$cache_root/.''${name}.XXXXXX")" || return 1

          if ! fetch_checkout "$temporary/source" "$name" "$repository" "$ref" "$rev" "$skill_path"; then
            rm -rf "$temporary"
            return 1
          fi

          printf '%s\n' "$expected_marker" > "$temporary/source/.dotfiles-source" || return 1
          rm -rf "$cache_dir"
          mv "$temporary/source" "$cache_dir" || return 1
          rm -rf "$temporary"
        fi

        mkdir -p "$target_root" || return 1
        rm -rf "$target"
        mkdir -p "$target" || return 1
        cp -R "$cache_dir/$skill_path/." "$target/" || return 1
        chmod -R u+w "$target" || return 1
        # A skill at the repository root (path ".") would otherwise ship the checkout metadata.
        rm -rf "$target/.git" "$target/.dotfiles-source"
      }

      # Every step returns explicitly: optional skills run inside `if`, where errexit is off.
      fetch_checkout() {
        local checkout="$1"
        local name="$2"
        local repository="$3"
        local ref="$4"
        local rev="$5"
        local skill_path="$6"
        local actual

        git init --quiet "$checkout" || return 1
        git -C "$checkout" remote add origin "$repository" || return 1
        git -C "$checkout" fetch --depth 1 origin "$ref" || return 1

        actual="$(git -C "$checkout" rev-parse 'FETCH_HEAD^{commit}')" || return 1
        if [[ "$actual" != "$rev" ]]; then
          echo "agent skill $name: ref '$ref' resolved to $actual, expected rev $rev (pinned in agent-skills.toml)." >&2
          echo "agent skill $name: review the upstream diff between $rev and $actual, then update rev in agent-skills.toml if it's safe." >&2
          return 1
        fi

        git -C "$checkout" checkout --detach --quiet FETCH_HEAD || return 1

        if [[ ! -f "$checkout/$skill_path/SKILL.md" ]]; then
          echo "agent skill $name: SKILL.md not found at $skill_path in $repository@$ref" >&2
          return 1
        fi
      }

      # An optional skill (overlay-provided, possibly private) must not break the rebuild:
      # warn and keep the copy that is already installed.
      run_sync() {
        local optional="$1"
        local agent_state="unset"
        shift
        if [[ "$optional" == true ]]; then
          if [[ -n "''${SSH_AUTH_SOCK:-}" ]]; then agent_state="set"; fi
          if ! sync_skill "$@"; then
            echo "agent skill $1: sync failed, keeping the installed copy (SSH_AUTH_SOCK is $agent_state)." >&2
          fi
        else
          sync_skill "$@"
        fi
      }

      ${syncCommands}

      if [[ -f "$managed_state" ]]; then
        while IFS= read -r previous_target; do
          if ! grep -Fxq -- "$previous_target" "$desired_state"; then
            case "$previous_target" in
              "$HOME/.agents/skills/"*|"$HOME/.claude/skills/"*) rm -rf "$previous_target" ;;
            esac
          fi
        done < "$managed_state"
      fi
      mv "$desired_state" "$managed_state"
      trap - EXIT
    '';
  };
in
{
  options.agentSkills.skills = lib.mkOption {
    description = ''
      Pinned external agent skills. agent-skills.toml feeds the public entries;
      overlay/nix/home.nix may append its own (set `optional = true` for private
      sources so a failed fetch warns instead of failing the rebuild).
    '';
    default = [ ];
    type = lib.types.listOf (lib.types.submodule {
      options = {
        name = lib.mkOption { type = lib.types.str; };
        repository = lib.mkOption { type = lib.types.str; };
        path = lib.mkOption { type = lib.types.str; };
        ref = lib.mkOption { type = lib.types.str; };
        rev = lib.mkOption { type = lib.types.str; };
        targets = lib.mkOption { type = lib.types.listOf (lib.types.enum supportedTargets); };
        license = lib.mkOption { type = lib.types.str; default = ""; };
        optional = lib.mkOption { type = lib.types.bool; default = false; };
      };
    });
  };

  config = {
    agentSkills.skills = manifest.skill or [ ];

    home.packages = [ agentSkillsSync ];

    # The manifest is pinned, so this makes an installed skill reproducible without
    # asking gh to resolve a moving "latest" version during Home Manager activation.
    home.activation.syncExternalAgentSkills = lib.hm.dag.entryAfter [ "linkGeneration" "installCodexSkills" ] ''
      if [[ -z "''${DRY_RUN:-}" ]]; then
        ${agentSkillsSync}/bin/agent-skills-sync
      fi
    '';
  };
}
