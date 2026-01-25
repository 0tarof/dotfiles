# ==========================================================================
# Dotfiles - declarative symlinks managed by Home Manager
# ==========================================================================
{ config, lib, dotfilesDir, ... }:

let
  # Zsh overlay path
  zshOverlayPath = ../overlay/zsh;
  hasZshOverlay = builtins.pathExists zshOverlayPath;
in
{
  # ==========================================================================
  # Zsh configuration files
  # ==========================================================================
  # p10k theme file (zsh is managed by programs.zsh)
  home.file.".config/zsh/.p10k.zsh".source = ../zsh/.p10k.zsh;
  
  # Overlay directory for company-specific zsh configs (if exists)
  home.file.".config/zsh/overlay" = lib.mkIf hasZshOverlay {
    source = zshOverlayPath;
    recursive = true;
  };

  # ==========================================================================
  # Config directories -> ~/.config/*
  # ==========================================================================
  home.file.".config/tmux" = {
    source = ../tmux;
    recursive = true;
  };
  
  home.file.".config/git" = {
    source = ../git;
    recursive = true;
  };
  
  home.file.".config/mise" = {
    source = ../mise;
    recursive = true;
  };
  
  home.file.".config/ghostty" = {
    source = ../ghostty;
    recursive = true;
  };

  home.file.".config/zellij" = {
    source = ../zellij;
    recursive = true;
  };

  home.file.".config/nvim" = {
    source = ../nvim;
    recursive = true;
  };
  
  # Git config in home directory
  home.file.".gitconfig".source = ../.gitconfig;
  
  # ==========================================================================
  # Claude Code configuration
  # ==========================================================================
  home.file.".claude/commands" = {
    source = ../claude/commands;
    recursive = true;
  };
  
  home.file.".claude/skills" = {
    source = ../claude/skills;
    recursive = true;
  };
  
  home.file.".claude/rules" = {
    source = ../claude/rules;
    recursive = true;
  };
  
  home.file.".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/settings.json";
  
  # ==========================================================================
  # Cursor configuration
  # ==========================================================================
  home.file.".cursor/commands" = {
    source = ../cursor/commands;
    recursive = true;
  };
  
  # ==========================================================================
  # Bin scripts (except nix-rebuild which is defined in scripts.nix)
  # ==========================================================================
  home.file."bin/ch" = {
    source = ../bin/ch;
    executable = true;
  };
  
  home.file."bin/git-delete-merged-branch" = {
    source = ../bin/git-delete-merged-branch;
    executable = true;
  };
  
  home.file."bin/gws" = {
    source = ../bin/gws;
    executable = true;
  };
}
