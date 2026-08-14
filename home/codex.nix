# ==========================================================================
# Codex configuration
# ==========================================================================
{ lib, ... }:

let
  # Global Codex skills managed by dotfiles live in agents/skills and are
  # copied to ~/.agents/skills during activation. Keep .agents/skills reserved
  # for repo-local skills so this dotfiles repo does not double-load them.
  codexSkillsDir = ../agents/skills;
  hasCodexSkills = builtins.pathExists codexSkillsDir;
  codexSkillEntries =
    if hasCodexSkills
    then builtins.readDir codexSkillsDir
    else { };
  codexSkillNames =
    builtins.filter
      (name: codexSkillEntries.${name} == "directory")
      (builtins.attrNames codexSkillEntries);

  installSkillCommands = lib.concatMapStringsSep "\n" (name: ''
    install_skill ${lib.escapeShellArg name}
  '') codexSkillNames;
in
{
  home.file = {
    ".codex/AGENTS.md" = {
      source = ../codex/AGENTS.md;
      force = true;
    };
  };

  # Codex currently ignores skills when SKILL.md itself is a symlink. Home
  # Manager's recursive home.file source creates symlinked files into /nix/store,
  # so copy managed skills as real files during activation instead.
  #
  # Keep Codex skills in ~/.agents/skills only. Older activations also copied
  # them to ~/.codex/skills, which makes Codex load the same skill twice.
  home.activation.installCodexSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      mkdir -p "$HOME/.agents/skills"

      install_skill() {
        local name="$1"
        local source="${codexSkillsDir}/$name"
        local target="$HOME/.agents/skills/$name"
        local legacy_target="$HOME/.codex/skills/$name"

        rm -rf "$target"
        mkdir -p "$target"
        cp -R "$source/." "$target/"
        chmod -R u+w "$target"

        rm -rf "$legacy_target"
      }

      ${installSkillCommands}
    fi
  '';
}
