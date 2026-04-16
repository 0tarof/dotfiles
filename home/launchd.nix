# ==========================================================================
# Launch Agents - macOS periodic tasks managed by Home Manager
# NOTE: launchd is Darwin-only. On Linux, this module is a no-op.
# ==========================================================================
{ config, lib, pkgs, ... }:

{
  launchd.agents.cmux-backup-session = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "com.0tarof.cmux-backup-session";
      ProgramArguments = [
        "${config.home.homeDirectory}/bin/cmux-backup-session"
      ];
      StartInterval = 300; # 5 minutes
      StandardOutPath = "/tmp/cmux-backup-session.log";
      StandardErrorPath = "/tmp/cmux-backup-session.log";
    };
  };
}
