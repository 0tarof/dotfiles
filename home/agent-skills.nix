# ==========================================================================
# External agent skills - pinned Git sources projected into agent skill dirs
# ==========================================================================
{ lib, pkgs, ... }:

let
  manifest = builtins.fromTOML (builtins.readFile ../agent-skills.toml);
  supportedTargets = [ "agents" "claude" ];
  rawSkills = manifest.skill or [ ];

  validateSkill = skill:
    assert builtins.match "^[A-Za-z0-9._-]+$" skill.name != null;
    assert skill.name != "." && skill.name != "..";
    assert !(lib.hasPrefix "/" skill.path) && !(lib.hasInfix ".." skill.path);
    assert lib.all (target: builtins.elem target supportedTargets) skill.targets;
    skill;

  skills = map validateSkill rawSkills;

  syncCommands = lib.concatMapStringsSep "\n" (skill:
    lib.concatMapStringsSep "\n" (target: ''
      sync_skill \
        ${lib.escapeShellArg skill.name} \
        ${lib.escapeShellArg skill.repository} \
        ${lib.escapeShellArg skill.ref} \
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
        local skill_path="$4"
        local target_kind="$5"
        local cache_dir="$cache_root/$name"
        local marker="$cache_dir/.dotfiles-source"
        local expected_marker="$repository#$ref"
        local target_root
        local target

        target_root="$(target_root_for "$target_kind")"
        target="$target_root/$name"
        printf '%s\n' "$target" >> "$desired_state"

        if [[ "$force" == true || ! -f "$marker" || "$(<"$marker")" != "$expected_marker" || ! -f "$cache_dir/$skill_path/SKILL.md" ]]; then
          local temporary
          local checkout
          temporary="$(mktemp -d "$cache_root/.''${name}.XXXXXX")"
          checkout="$temporary/source"

          cleanup_temporary() { rm -rf "$temporary"; }
          trap cleanup_temporary RETURN

          git init --quiet "$checkout"
          git -C "$checkout" remote add origin "$repository"
          git -C "$checkout" fetch --depth 1 origin "$ref"
          git -C "$checkout" checkout --detach --quiet FETCH_HEAD

          if [[ ! -f "$checkout/$skill_path/SKILL.md" ]]; then
            echo "agent skill $name: SKILL.md not found at $skill_path in $repository@$ref" >&2
            return 1
          fi

          printf '%s\n' "$expected_marker" > "$checkout/.dotfiles-source"
          rm -rf "$cache_dir"
          mv "$checkout" "$cache_dir"
          trap - RETURN
          rm -rf "$temporary"
        fi

        mkdir -p "$target_root"
        rm -rf "$target"
        mkdir -p "$target"
        cp -R "$cache_dir/$skill_path/." "$target/"
        chmod -R u+w "$target"
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
  home.packages = [ agentSkillsSync ];

  # The manifest is pinned, so this makes an installed skill reproducible without
  # asking gh to resolve a moving "latest" version during Home Manager activation.
  home.activation.syncExternalAgentSkills = lib.hm.dag.entryAfter [ "linkGeneration" "installCodexSkills" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      ${agentSkillsSync}/bin/agent-skills-sync
    fi
  '';
}
