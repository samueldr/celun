{ config, lib, pkgs, ... }:

let
  enabled = config.filesystem == "btrfs";
  inherit (lib)
    escapeShellArg
    mkIf
    mkMerge
    mkOption
    optionalString
    types
  ;
  typeUuid = types.strMatching (
    let hex = "[0-9a-fA-F]"; in
    "${hex}{8}-${hex}{4}-${hex}{4}-${hex}{4}-${hex}{12}"
  );

  inherit (config) label sectorSize blockSize;
  inherit (config.btrfs) partitionID;
in
{
  options.btrfs = {
    partitionID = mkOption {
      type = types.nullOr typeUuid;
      example = "45454545-4545-4545-4545-454545454545";
      default = null;
      description = ''
        Volume ID of the filesystem.
      '';
    };
  };

  config = mkMerge [
    { availableFilesystems = [ "btrfs" ]; }
    (mkIf enabled {
      nativeBuildInputs = with pkgs.buildPackages; [
        btrfs-progs
      ];

      blockSize = config.helpers.size.KiB 4;
      sectorSize = lib.mkDefault 512;

      # Generated an empty filesystem, it was 114294784 bytes long.
      # Rounded up to 110MiB.
      minimumSize = config.helpers.size.MiB 110;

      computeMinimalSize = ''
      '';

      buildPhases = {
        copyPhase = ''
          mkfs.btrfs \
            -r . \
            ${optionalString (partitionID != null) "-U ${partitionID}"} \
            ${optionalString (label != null) "-L ${escapeShellArg label}"} \
            ${optionalString (config.size == null) "--shrink"} \
            "$img"
        '';

        checkPhase = ''
          faketime -f "1970-01-01 00:00:01" btrfs check "$img"
        '';
      };
    })
  ];
}
