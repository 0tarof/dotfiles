# ==========================================================================
# Codex configuration
# ==========================================================================
{ lib, ... }:

let
  codexSkillsDir = ../.agents/skills;
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
  home.activation.installCodexSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      mkdir -p "$HOME/.agents/skills" "$HOME/.codex/skills"

      install_skill() {
        local name="$1"
        local source="${codexSkillsDir}/$name"
        local root
        local target

        for root in "$HOME/.agents/skills" "$HOME/.codex/skills"; do
          target="$root/$name"
          rm -rf "$target"
          mkdir -p "$target"
          cp -R "$source/." "$target/"
          chmod -R u+w "$target"
        done
      }

      ${installSkillCommands}
    fi
  '';
}
