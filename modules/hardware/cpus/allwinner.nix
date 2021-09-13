{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge mkOption types;
  cfg = config.hardware.cpus;
in
{
  options.hardware.cpus = {
    allwinner-a64.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable when system is an Allwinner A64.";
      internal = true;
    };
    allwinner-f1c100s.enable = mkOption {
      # CPU: ARM926EJ-S (ARMv5TE) @ 533MHz
      # 32MiB of embedded RAM
      type = types.bool;
      default = false;
      description = "Enable when system is an Allwinner F1C100s.";
      internal = true;
    };
  };

  config = mkMerge [
    (lib.mkIf cfg.allwinner-a64.enable {
      celun.system.system = "aarch64-linux";
      wip.u-boot = {
        enable = true;
        fdt_addr_r     = "0x4FA00000";
        kernel_addr_r  = "0x40080000";
        pxefile_addr_r = "0x4FD00000";
        ramdisk_addr_r = "0x4FF00000";
      };

      wip.kernel.structuredConfig =
        with lib.kernel;
        let
          inherit (config.wip.kernel) features;
        in
        lib.mkMerge [
          (lib.mkIf features.serial {
            # Needed or serial drops off...
            # Note that this is stripped from savedefconfig...
            # ... and using tinyconfig does not play nice.
            # XXX # SERIAL_8250_DW = yes;
            # XXX # SERIAL_OF_PLATFORM = yes;
          })
        ]
      ;
    })
    (lib.mkIf cfg.allwinner-f1c100s.enable {
      celun.system.system = "armv5tel-linux";
      device = {
        config.allwinner = {
          enable = true;
          fel-env = {
            fdt_addr_r     = "0x80C00000";
            kernel_addr_r  = "0x80500000";
            ramdisk_addr_r = "0x80E00000";
            scriptaddr     = "0x80C50000";
          };
        };
      };
      nixpkgs.overlays = [(final: super: {
        sunxi-tools = super.sunxi-tools.overrideAttrs({ buildInputs ? [], ...}: {
          name = "sunxi-tools-f1c100s";
          src = final.fetchFromGitHub {
            owner = "samueldr";
            repo = "sunxi-tools";
            rev = "56eb6e8a4222ec9b5f6b978efb73edda66878162";
            sha256 = "0l5b5y99lkm7kmyfs7xzx279aaz1cn89zjgl6fm7blzw43j92qzy";
          };
          buildInputs = buildInputs ++ [
            final.dtc
          ];
        });
      })];
    })
  ];
}
