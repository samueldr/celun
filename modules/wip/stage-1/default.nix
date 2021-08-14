{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
  ;

  cfg = config.wip.stage-1;

  compressed = {
    none = cfg.cpio;
    xz = pkgs.runCommandNoCC "${cfg.cpio.name}.xz" {
      nativeBuildInputs = [
        pkgs.buildPackages.xz
      ];
    } ''
      cat ${cfg.cpio} | xz -9 -e --check=crc32 > $out
    '';
  };
in
{
  options.wip.stage-1 = {
    cpio = mkOption {
      type = types.package;
      internal = true;
      description = ''
        While the modules system usage is preferrable, users can override the
        cpio archive in use for the initramfs here.
      '';
    };

    output = {
      initramfs = mkOption {
        type = types.package;
        internal = true;
      };
    };

    compression = mkOption {
      default = "none";
      type = types.enum (builtins.attrNames compressed);
      description = ''
        Compression scheme used for the stage-1 image.

        > **Tip:** When bundling the initramfs in the kernel, leave compression
        > set to none, and rely on the kernel's own compression if available.
      '';
    };

    buildInKernel = mkOption {
      default = false;
      type = types.bool;
      description = ''
        Build the initramfs in the kernel image.

        > **Tip:** Leave this set to false for development purposes, unless you
        > like compiling a full kernel every builds.
      '';
    };
  };

  config = {
    wip.stage-1.output.initramfs = compressed.${cfg.compression};
    wip.kernel = {
      structuredConfig = with lib.kernel; mkMerge [
        (mkIf cfg.buildInKernel {
          INITRAMFS_SOURCE = freeform ''"${cfg.output.initramfs}"'';
        })
        (mkIf (cfg.compression != "none") {
          "RD_${lib.toUpper cfg.compression}" = yes;
        })
      ];
    };

    wip.stage-1.cpio = lib.mkDefault (pkgs.buildPackages.mkCpio {
      name = pkgs.smolix.minimal-initramfs.name + ".cpio";
      list = ''"${pkgs.smolix.minimal-initramfs}/files.list"'';
    });
  };
}
