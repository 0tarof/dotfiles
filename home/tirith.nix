# ==========================================================================
# Tirith - shell and agent command guard
# ==========================================================================
{ inputs, lib, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  tirith = inputs.tirith.packages.${system}.default.overrideAttrs (_: {
    # Upstream still references removed darwin.apple_sdk.frameworks.* stubs.
    buildInputs = pkgs.lib.optionals pkgs.stdenv.isDarwin [
      pkgs.apple-sdk
    ];
  });
in
{
  home.packages = [
    tirith
  ];

  home.file.".config/tirith/gateway.yaml".text = ''
    # Tirith MCP Gateway configuration
    guarded_tools:
      - pattern: "^(Bash|bash|shell|sh|zsh|terminal|Terminal|terminal_exec|terminalExec|run_shell|runShell|run_shell_command|runShellCommand|shell_command|shellCommand|command_shell|commandShell)$"
        command_paths: ["/arguments/command", "/arguments/cmd", "/arguments/script", "/arguments/code", "/command", "/cmd", "/script", "/code"]
        shell: posix

      - pattern: "^(pwsh|powershell|PowerShell|pwsh_command|pwshCommand|powershell_command|powershellCommand)$"
        command_paths: ["/arguments/command", "/arguments/cmd", "/arguments/script", "/arguments/code", "/command", "/cmd", "/script", "/code"]
        shell: powershell

      - pattern: "^(run_command|runCommand|execute|execute_command|executeCommand|exec|exec_command|execCommand|run_cmd|runCmd|command_exec|commandExec)$"
        command_paths: ["/arguments/command", "/arguments/cmd", "/arguments/script", "/arguments/code", "/command", "/cmd", "/script", "/code"]
        shell: posix

    policy:
      warn_action: "forward"
      fail_mode: "open"
      timeout_ms: 10000
      max_message_bytes: 1048576
  '';

  programs.zsh.envExtra = lib.mkAfter ''
    # Guard non-interactive zsh command runs such as `zsh -lc ...`.
    # Cursor/VS Code WSL integration resolves env via `zsh -ic "exec env ..."`.
    # That command embeds exported tokens (e.g. HOMEBREW_GITHUB_API_TOKEN) and must
    # not be blocked here or the terminal fails to start.
    if [[ -n "''${ZSH_EXECUTION_STRING:-}" \
       && "''${TIRITH_ZSHENV_SKIP:-}" != "1" \
       && -z "''${VSCODE_RESOLVING_ENVIRONMENT:-}" \
       && "''${ZSH_EXECUTION_STRING}" != exec\ env* ]]; then
      _tirith_bin="''${TIRITH_BIN:-${tirith}/bin/tirith}"
      if [[ "$_tirith_bin" != */* ]]; then
        _tirith_bin="$(command -v "$_tirith_bin" 2>/dev/null || true)"
      fi

      if [[ -z "$_tirith_bin" || ! -x "$_tirith_bin" ]]; then
        echo "tirith: command not found - command blocked for safety" >&2
        exit 1
      fi

      _tirith_tmp="$(mktemp 2>/dev/null)" || {
        echo "tirith: could not create temp file - command blocked for safety" >&2
        exit 1
      }

      "$_tirith_bin" check --non-interactive --shell posix -- "$ZSH_EXECUTION_STRING" >"$_tirith_tmp" 2>&1
      _tirith_rc=$?

      if [[ $_tirith_rc -eq 0 ]]; then
        rm -f "$_tirith_tmp"
      elif [[ $_tirith_rc -eq 1 ]]; then
        cat "$_tirith_tmp" >&2
        rm -f "$_tirith_tmp"
        exit 1
      elif [[ $_tirith_rc -eq 2 ]]; then
        cat "$_tirith_tmp" >&2
        rm -f "$_tirith_tmp"
      else
        cat "$_tirith_tmp" >&2
        echo "tirith: unexpected exit code $_tirith_rc" >&2
        rm -f "$_tirith_tmp"
        exit 1
      fi

      unset _tirith_bin _tirith_tmp _tirith_rc
    fi
  '';

  programs.zsh.initContent = lib.mkAfter ''
    if [[ -o interactive ]]; then
      eval "$(${tirith}/bin/tirith init --shell zsh)"
    fi
  '';

  home.activation.setupTirithCodexGateway = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      codex_bin=""
      for candidate in \
        "/Applications/Codex.app/Contents/Resources/codex" \
        "$HOME/.local/share/mise/installs/npm-openai-codex/latest/bin/codex" \
        "$HOME/.local/share/mise/shims/codex"; do
        if [[ -x "$candidate" ]]; then
          codex_bin="$candidate"
          break
        fi
      done

      if [[ -z "$codex_bin" ]] && command -v codex >/dev/null 2>&1; then
        codex_bin="$(command -v codex)"
      fi

      if [[ -n "$codex_bin" ]]; then
        export CODEX_HOME="''${CODEX_HOME:-$HOME/.codex}"
        mkdir -p "$CODEX_HOME"
        "$codex_bin" mcp add tirith-gateway -- \
          "${tirith}/bin/tirith" gateway run \
          --upstream-bin "${tirith}/bin/tirith" \
          --upstream-arg mcp-server \
          --config "$HOME/.config/tirith/gateway.yaml" >/dev/null
      else
        echo "tirith: codex command not found; skipping Codex MCP gateway setup" >&2
      fi
    fi
  '';
}
