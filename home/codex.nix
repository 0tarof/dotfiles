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

  userSkillHomeFiles = builtins.listToAttrs (map
    (name: {
      name = ".agents/skills/${name}";
      value = {
        source = codexSkillsDir + "/${name}";
        recursive = true;
      };
    })
    codexSkillNames);

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
  # Codex discovers user-authored skills from ~/.agents/skills. Keep a
  # ~/.codex/skills mirror for existing sessions and older local builds that
  # already inspect it, while managing each directory individually so bundled
  # directories such as ~/.codex/skills/.system remain untouched.
  home.file = userSkillHomeFiles // codexSkillHomeFiles // {
    ".codex/AGENTS.md" = {
      source = ../codex/AGENTS.md;
      force = true;
    };
  };
}
