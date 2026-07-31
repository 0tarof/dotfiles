# ==========================================================================
# Dotfiles - declarative symlinks managed by Home Manager
# ==========================================================================
{ config, lib, pkgs, dotfilesDir, ... }:

let
  # Zsh overlay path
  zshOverlayPath = ../overlay/zsh;
  hasZshOverlay = builtins.pathExists zshOverlayPath;
  reviewKnowledgeSkillPath = ../.agents/skills/review-knowledge-collect;
  hasReviewKnowledgeSkill = builtins.pathExists reviewKnowledgeSkillPath;
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
  
  # mise は cwd から上位に向かって `mise/config.toml` をプロジェクト設定として自動検出する。
  # リポジトリ内で作業するとグローバル設定が二重に読まれ、credential_command が
  # 「non-global config なので無視」と警告されるので、ソース側は検出されない名前で持つ。
  home.file.".config/mise/config.toml".source = ../mise/global.toml;

  home.file.".config/uv" = {
    source = ../uv;
    recursive = true;
  };

  # Empty sbtopts to prevent nix-packaged sbt from enforcing a specific Java version
  home.file.".config/sbt/sbtopts".text = "";
  
  home.file.".config/ghostty" = {
    source = ../ghostty;
    recursive = true;
  };

  # cmux reads Ghostty config from Application Support path
  home.file."Library/Application Support/com.mitchellh.ghostty/config".source = ../ghostty/config;

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

  # npm global config
  home.file.".npmrc".source = ../.npmrc;

  # ==========================================================================
  # Docker CLI plugins
  # ==========================================================================
  # docker-client には plugin が同梱されないので、`docker compose` /
  # `docker buildx` として呼べるよう CLI plugin ディレクトリにリンクする。
  home.file.".docker/cli-plugins/docker-compose".source =
    "${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose";

  home.file.".docker/cli-plugins/docker-buildx".source =
    "${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx";

  # ==========================================================================
  # Claude Code configuration
  # ==========================================================================
  home.file.".claude/skills" = {
    source = ../claude/skills;
    recursive = true;
  };

  home.file.".claude/skills/review-knowledge-collect" = lib.mkIf hasReviewKnowledgeSkill {
    source = reviewKnowledgeSkillPath;
    recursive = true;
  };
  
  home.file.".claude/rules" = {
    source = ../claude/rules;
    recursive = true;
  };
  
  home.file.".claude/hooks" = {
    source = ../claude/hooks;
    recursive = true;
  };

  home.file.".claude/CLAUDE.md".source = ../claude/CLAUDE.md;

  # Claude Code からの設定変更を許容
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

  home.file."bin/cmux-backup-session" = {
    source = ../bin/cmux-backup-session;
    executable = true;
  };
}
