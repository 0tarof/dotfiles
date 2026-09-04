# ==========================================================================
# gh extensions - 宣言的に固定する GitHub CLI 拡張
# ==========================================================================
# `gh extension install` は ~/.local/share/gh/extensions 配下に実バイナリを
# 置くため、AI エージェントが調べ物の途中で入れたものが nix の管理外に残る。
# ここで store のバイナリへリンクし、入っている拡張と dotfiles を一致させる。
{ pkgs, ... }:

let
  version = "0.1.1";

  # 公式リリースは OS/arch ごとの単一バイナリで配布される。
  assets = {
    aarch64-darwin = { name = "darwin-arm64"; hash = "sha256-8Jqssu5y/bHUAe5PW5DgYpGahS/Dx7Zr8bGoUxBGF9g="; };
    x86_64-darwin = { name = "darwin-amd64"; hash = "sha256-QHQPgmRcKMTh2kfGvQKmrEl9OCpFfBCTaUozaxdQr3E="; };
    aarch64-linux = { name = "linux-arm64"; hash = "sha256-LaE/jEbydwI3x0SzQatr6fB1CFhaZ2JjTEqIqjVUYLw="; };
    x86_64-linux = { name = "linux-amd64"; hash = "sha256-ntEDk0+rD5DTNB/fxKNCeFOW059WIfxzE6YmAs4rVGI="; };
  };

  asset = assets.${pkgs.stdenv.hostPlatform.system};

  # nixpkgs の gh-stack は buildGoModule 版が v0.0.4 で止まっているため、
  # リリースバイナリをそのまま配置する。
  gh-stack = pkgs.stdenvNoCC.mkDerivation {
    pname = "gh-stack";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/github/gh-stack/releases/download/v${version}/${asset.name}";
      inherit (asset) hash;
    };

    dontUnpack = true;
    # 配布バイナリの署名を壊さないため strip させない
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/gh-stack"
      runHook postInstall
    '';

    meta = {
      description = "GitHub CLI extension to use stacked PRs";
      homepage = "https://github.com/github/gh-stack";
      mainProgram = "gh-stack";
      platforms = builtins.attrNames assets;
    };
  };
in
{
  # gh は PATH ではなく extensions ディレクトリを探すので、そこへ直接リンクする。
  # manifest.yml は置かない（あると `gh extension upgrade` が store を上書きしようとする）。
  home.file.".local/share/gh/extensions/gh-stack/gh-stack".source = "${gh-stack}/bin/gh-stack";
}
