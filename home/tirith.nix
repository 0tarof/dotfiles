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
  tirithGatewayConfig = ''
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
  tirithGatewayConfigFile = pkgs.writeText "tirith-gateway.yaml" tirithGatewayConfig;
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
  home.file.".config/tirith/gateway.yaml".text = tirithGatewayConfig;

  # Codex marks its non-interactive shell sessions with CODEX_SHELL=1. Scope
  # the zshenv guard to that marker so ordinary zsh -ilc and IDE probes keep
  # working while commands launched by Codex are checked before execution.
  programs.zsh.envExtra = lib.mkAfter ''
    if [[ -n "''${ZSH_EXECUTION_STRING:-}" \
       && "''${CODEX_SHELL:-}" == "1" \
       && "''${TIRITH_ZSHENV_SKIP:-}" != "1" \
       && -z "''${VSCODE_RESOLVING_ENVIRONMENT:-}" ]]; then
      _tirith_output=$("${tirith}/bin/tirith" check --non-interactive --shell posix -- "$ZSH_EXECUTION_STRING" 2>&1)
      _tirith_rc=$?

      if [[ $_tirith_rc -eq 1 ]]; then
        [[ -z "$_tirith_output" ]] || builtin print -r -- "$_tirith_output" >&2
        exit 1
      elif [[ $_tirith_rc -eq 2 ]]; then
        [[ -z "$_tirith_output" ]] || builtin print -r -- "$_tirith_output" >&2
      elif [[ $_tirith_rc -ne 0 ]]; then
        [[ -z "$_tirith_output" ]] || builtin print -r -- "$_tirith_output" >&2
        builtin print -r -- "tirith: unexpected exit code $_tirith_rc" >&2
        exit 1
      fi

      builtin unset _tirith_output _tirith_rc
    fi
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
        "/Applications/ChatGPT.app/Contents/Resources/codex" \
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
        export PATH="/Applications/ChatGPT.app/Contents/Resources:$HOME/.local/share/mise/shims:$HOME/.local/share/mise/installs/node/latest/bin:$PATH"
        export CODEX_HOME="''${CODEX_HOME:-$HOME/.codex}"
        mkdir -p "$CODEX_HOME"

        add_tirith_gateway() {
          "$codex_bin" mcp add tirith-gateway -- \
            "${tirith}/bin/tirith" gateway run \
            --upstream-bin "${tirith}/bin/tirith" \
            --upstream-arg mcp-server \
            --config "${tirithGatewayConfigFile}" >/dev/null
        }

        current_registration="$("$codex_bin" mcp get --json tirith-gateway 2>/dev/null || true)"
        if [[ -n "$current_registration" ]] && printf '%s' "$current_registration" | \
          ${pkgs.jq}/bin/jq -e --arg command "${tirith}/bin/tirith" --arg config "${tirithGatewayConfigFile}" \
            '(.transport.command == $command) and ((.transport.args // []) | index($config) != null)' >/dev/null 2>&1; then
          :
        elif [[ -z "$current_registration" ]] || printf '%s' "$current_registration" | \
          ${pkgs.jq}/bin/jq -e '(.transport.command // "") | endswith("/bin/tirith")' >/dev/null 2>&1; then
          if [[ -n "$current_registration" ]]; then
            "$codex_bin" mcp remove tirith-gateway >/dev/null 2>&1 || true
          fi
          if ! add_tirith_gateway; then
            echo "tirith: codex MCP gateway setup failed; registration may need manual repair" >&2
          fi
        else
          echo "tirith: existing non-Tirith codex gateway registration left unchanged" >&2
        fi
      else
        echo "tirith: codex command not found; skipping Codex MCP gateway setup" >&2
      fi
    fi
  '';
}
