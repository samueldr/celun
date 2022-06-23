{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.hardware.cpus;
in
{
  options.hardware.cpus = {
    sigmastar-ssd202d.enable = mkOption {
      # CPU: Cortex-A7 @ 1.2GHz
      # 128MiB of embedded DDR3
      type = types.bool;
      default = false;
      description = "Enable when system is a SigmaStar SSD202D.";
      internal = true;
    };
  };

  config = mkMerge [
    (lib.mkIf cfg.sigmastar-ssd202d.enable {
      celun.system.system = "armv7l-linux";
    })
  ];
}

