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
  tirithPolicy = pkgs.writeText "tirith-policy.yaml" ''
    severity_overrides:
      non_ascii_path: LOW
  '';
in
{
  home.packages = [
    tirith
  ];

  # Japanese paths are legitimate in day-to-day commands. Keep this finding in
  # Tirith's audit data without printing a warning for every occurrence; hostname
  # homoglyph and mixed-script detection remains at its default severity.
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

  programs.zsh.initContent = lib.mkAfter ''
    if [[ -o interactive ]]; then
      eval "$(${tirith}/bin/tirith init --shell zsh)"
    fi
  '';

  # Tirith rejects Home Manager's symlinked home.file entries for policies.
  # Copy this managed policy as a regular file instead.
  home.activation.installTirithPolicy = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [[ -z "''${DRY_RUN:-}" ]]; then
      ${pkgs.coreutils}/bin/install -Dm644 ${tirithPolicy} "$HOME/.config/tirith/policy.yaml"
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
        export PATH="$HOME/.local/share/mise/shims:$HOME/.local/share/mise/installs/node/latest/bin:$PATH"
        export CODEX_HOME="''${CODEX_HOME:-$HOME/.codex}"
        mkdir -p "$CODEX_HOME"
        if ! "$codex_bin" mcp add tirith-gateway -- \
          "${tirith}/bin/tirith" gateway run \
          --upstream-bin "${tirith}/bin/tirith" \
          --upstream-arg mcp-server \
          --config "$HOME/.config/tirith/gateway.yaml" >/dev/null; then
          echo "tirith: codex MCP gateway setup failed; skipping" >&2
        fi
      else
        echo "tirith: codex command not found; skipping Codex MCP gateway setup" >&2
      fi
    fi
  '';
}
