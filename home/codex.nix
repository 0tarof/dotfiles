# ==========================================================================
# Codex configuration
# ==========================================================================
{ ... }:

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

  codexSkillHomeFiles = builtins.listToAttrs (map
    (name: {
      name = ".codex/skills/${name}";
      value = {
        source = codexSkillsDir + "/${name}";
        recursive = true;
      };
    })
    codexSkillNames);
in
{
  # Manage each skill directory individually so existing Codex-managed
  # directories such as ~/.codex/skills/.system remain untouched.
  home.file = codexSkillHomeFiles // {
    ".codex/AGENTS.md" = {
      source = ../codex/AGENTS.md;
      force = true;
    };
  };
}
