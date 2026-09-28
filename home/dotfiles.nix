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

  # Docker Desktop が起動のたびに ~/.docker/cli-plugins を自分のリンクで
  # 塗り替えるため、ここで plugin を管理すると activation が collision で
  # 落ちる。plugin は Docker Desktop 同梱のもの（daemon と版が揃う）に任せる。

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

  # リポジトリの settings.json は管理するキーだけを持ち、Claude Code が実行時に書く
  # model や autoMode はローカルの実ファイルにだけ残す。symlink で直結すると実行時の
  # 変更がすべて公開リポジトリの diff になり、自動生成された環境情報まで流れ込むため。
  # hooks と deny/ask はリポジトリの値で上書きし、allow だけはローカルの追加分を残す。
  home.activation.mergeClaudeSettings = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      settings="$HOME/.claude/settings.json"
      managed=${../claude/settings.json}
      mkdir -p "$HOME/.claude"

      # 旧構成の symlink は、中身を実ファイルとして引き継いでから外す。
      # linkGeneration より前に実ファイルにしておけば、Home Manager の古いリンクの
      # 掃除対象にならない。
      if [[ -L "$settings" ]]; then
        tmp="$(${pkgs.coreutils}/bin/mktemp "$settings.tmp.XXXXXX")"
        if ${pkgs.coreutils}/bin/cp -L "$settings" "$tmp" 2>/dev/null; then
          mv "$tmp" "$settings"
        else
          rm -f "$tmp" "$settings"
        fi
      fi

      if [[ ! -e "$settings" ]]; then
        ${pkgs.coreutils}/bin/install -m600 "$managed" "$settings"
      elif ${pkgs.jq}/bin/jq -e 'type == "object"' "$settings" >/dev/null 2>&1; then
        tmp="$(${pkgs.coreutils}/bin/mktemp "$settings.tmp.XXXXXX")"
        if ${pkgs.jq}/bin/jq -s '
          .[0] as $live
          | .[1] as $managed
          | ($live * $managed)
          | .hooks = $managed.hooks
          | .permissions.deny = ($managed.permissions.deny // [])
          | .permissions.ask = ($managed.permissions.ask // [])
          | .permissions.allow = (
              ($managed.permissions.allow // []) + ($live.permissions.allow // [])
              | reduce .[] as $rule ([]; if any(.[]; . == $rule) then . else . + [$rule] end)
            )
        ' "$settings" "$managed" > "$tmp"; then
          mv "$tmp" "$settings"
        else
          rm -f "$tmp"
          echo "claude: could not merge settings.json; leaving it unchanged" >&2
        fi
      else
        echo "claude: settings.json is not a JSON object; leaving it unchanged" >&2
      fi
    fi
  '';
  
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
