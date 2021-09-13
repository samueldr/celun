{ config, lib, pkgs, ... }:

/*

This is the shared implementation of common Allwinner specific details.

*/

let
  inherit (lib)
    concatStringsSep
    optionalString
    mapAttrsToList
    mkOption
    types
  ;
  inherit (pkgs)
    stdenv
  ;
  inherit (stdenv) hostPlatform isAarch64;
  kernel = config.wip.kernel.output;
  inherit (kernel) target;
  inherit (config.wip.stage-1.output) initramfs;
  inherit (config.device) dtbFiles nameForDerivation;

  cfg = config.device.config.allwinner;

  ubootPlatforms = {
    "aarch64-linux" = "arm64";
    "armv5tel-linux" = "arm";
    "armv6l-linux" = "arm";
    "armv7l-linux" = "arm";
  };

  bootcmd = pkgs.writeText "boot.cmd" ''
    setenv bootargs ${concatStringsSep " " config.boot.cmdline}

    echo
    echo === debug information ===
    echo
    echo bootargs: $bootargs
    echo
    echo kernel_addr_r:  $kernel_addr_r
    echo fdt_addr_r:     $fdt_addr_r
    echo ramdisk_addr_r: $ramdisk_addr_r
    echo
    echo === end of the debug information ===
    echo

    if test "$mmc_bootdev" != ""; then
      echo ":: Detected mmc booting"
      devtype="mmc"
    else
      echo "!!! Could not detect devtype !!!"
      exit
    fi

    if test "$devtype" = "mmc"; then
      devnum="$mmc_bootdev"
      echo ":: Booting from mmc $devnum"
    fi

    bootpart=""
    echo part number $devtype $devnum \$BOOT bootpart
    part number $devtype $devnum \$BOOT bootpart
    echo $bootpart

    # To stay compatible with the default assumptions from U-Boot, detect the
    # bootable legacy flag.
    if test "$bootpart" = ""; then
      echo "Could not find a partition with the partlabel '\ROOT'."
      echo "(looking at partitions marked bootable)"
      part list ''${devtype} ''${devnum} -bootable bootpart
      # This may print out an error message when there is only one result.
      # Though it still is fine.
      setexpr bootpart gsub ' .*' "" "$bootpart"
    fi

    if test "$bootpart" = ""; then
      echo "!!! Could not find 'boot' partition on $devtype $devnum !!!"
      exit
    fi

    echo ":: Booting from partition $bootpart"

    if load ''${devtype} ''${devnum}:''${bootpart} ''${kernel_addr_r} /kernel.img; then
      setenv boot_type boot
    else
      echo "!!! Failed to load kernel !!!"
      exit
    fi

    if load ''${devtype} ''${devnum}:''${bootpart} ''${fdt_addr_r} /dtbs/''${fdtfile}; then
      fdt addr ''${fdt_addr_r}
      fdt resize
    fi

    load ''${devtype} ''${devnum}:''${bootpart} ''${ramdisk_addr_r} /initramfs.img
    setenv ramdisk_size ''${filesize}

    ${if isAarch64 then ''
      echo booti ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
      booti ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
    '' else ''
      echo bootz ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
      bootz ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
    ''}
  '';
  bootscr = pkgs.runCommandNoCC "boot.scr" {
    nativeBuildInputs = [
      pkgs.buildPackages.ubootTools
    ];
  } ''
    mkimage  -C none -A ${ubootPlatforms.${pkgs.targetPlatform.system}} -T script -d ${bootcmd} $out
  '';

  fel-bootcmd =
    let
      script = pkgs.writeText "fel-boot.cmd" ''
        setenv bootargs ${concatStringsSep " " config.boot.cmdline}

        echo
        echo === debug information ===
        echo
        echo bootargs: $bootargs
        echo
        echo kernel_addr_r:  $kernel_addr_r
        echo fdt_addr_r:     $fdt_addr_r
        echo ramdisk_addr_r: $ramdisk_addr_r
        echo
        echo === end of the debug information ===
        echo

        # NOTE: hardcoded during build; this script is tightly coupled to the inputs.
        ramdisk_size=@initramfs_size@

        ${if isAarch64 then ''
          echo booti ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
          booti ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
        '' else ''
          echo bootz ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
          bootz ''${kernel_addr_r} ''${ramdisk_addr_r}:''${ramdisk_size} ''${fdt_addr_r};
        ''}
      '';
    in
    pkgs.runCommandNoCC "fel-boot.cmd" {} ''
      export initramfs_size
      initramfs_size=$(printf '0x%x' $(stat --dereference --format '%s' ${initramfs}))
      cat ${script} > $out
      substituteAllInPlace $out
    ''
  ;

  fel-bootscr = pkgs.runCommandNoCC "fel-boot.scr" {
    nativeBuildInputs = [
      pkgs.buildPackages.ubootTools
    ];
  } ''
    mkimage  -C none -A ${ubootPlatforms.${pkgs.targetPlatform.system}} -T script -d ${fel-bootcmd} $out
  '';
in
{
  options = {
    device.config.allwinner = {
      enable = lib.mkEnableOption "building for Allwinner SoCs";

      embedFirmware = mkOption {
        type = types.bool;
        description = ''
          Whether to embed the firmware in the filesystem image.

          **Must** be provided. It is likely preferable to use dedicated storage
          for the firmware if your board supports it.
        '';
      };

      firmwarePartition = mkOption {
        type = with types; oneOf [ path package ];
        description = ''
          Path to the firmware binary this board uses.
        '';
      };

      fel-firmware = mkOption {
        type = with types; oneOf [ path package ];
        default = cfg.firmwarePartition;
        defaultText = "\${cfg.firmwarePartition}";
        description = ''
          Firmware used by the FEL boot script.
        '';
      };

      fel-output = mkOption {
        type = types.package;
        internal = true;
      };

      fel-env = {
        fdt_addr_r = mkOption {
          type = types.str;
          description = ''
            Offset in memory for the FDT.

            This option is used only for the FEL boot script.
          '';
        };
        kernel_addr_r = mkOption {
          type = types.str;
          description = ''
            Offset in memory for the kernel.

            This option is used only for the FEL boot script.
          '';
        };
        ramdisk_addr_r = mkOption {
          type = types.str;
          description = ''
            Offset in memory for the initramfs.

            This option is used only for the FEL boot script.
          '';
        };
        scriptaddr = mkOption {
          type = types.str;
          description = ''
            Offset in memory for the script.

            This option is used only for the FEL boot script.
          '';
        };
      };

      output = mkOption {
        type = types.package;
        internal = true;
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    build.default = cfg.output;
    build.disk-image = cfg.output;
    build.fel = cfg.fel-output;
    device.config.allwinner = {
      output = (pkgs.celun.image-builder.evaluateDiskImage {
        config =
          { config, ... }:

          let inherit (config) helpers; in
          {
            name = "${nameForDerivation}-disk-image";
            partitioningScheme = "gpt";
            gpt.partitionEntriesCount = 48;

            partitions = [
              (lib.mkIf cfg.embedFirmware {
                name = "firmware";
                partitionLabel = "$FIRMWARE";
                partitionType = "67401509-72E7-4628-B1AF-EDD128E4316A";
                offset = 16 * 512 /* sectors */; # 8MiB from the start of the disk
                length = helpers.size.MiB 4;
                raw = cfg.firmwarePartition;
              })

              {
                name = "boot-partition";
                partitionLabel = "$BOOT";
                partitionType = "8DA63339-0007-60C0-C436-083AC8230908";
                bootable = true;
                filesystem = {
                  filesystem = "ext4";
                  label = "$BOOT";
                  extraPadding = helpers.size.MiB 32;
                  populateCommands = ''
                    cp ${bootscr} boot.scr
                    cp ${initramfs} initramfs.img
                    cp ${kernel}/${target} kernel.img

                    # There might not be any DTBs to install; on ARM the DTB files
                    # are built only if the proper ARCH_VENDOR config is set.
                    if [ -e ${kernel}/dtbs ]; then
                      (
                      shopt -s globstar
                      mkdir dtbs/
                      cp -fvr ${kernel}/dtbs/**/*.dtb ./dtbs
                      )
                    else
                      echo "Warning: no dtbs built on hostPlatform with DTB"
                    fi
                  '';
                };
              }

              # TODO: allow appending partitions (?)
            ];
          }
        ;
      }).config.output;

      fel-output = pkgs.buildPackages.writeShellScript "boot-${nameForDerivation}" ''
        set -e
        set -u
        PS4=" $ "

        PATH=$PATH:${lib.makeBinPath (with pkgs.buildPackages; [ sunxi-tools ])}
        kernel="${kernel}"
        initramfs="${initramfs}"

        ${concatStringsSep "\n" (
          mapAttrsToList (k: v: "${k}='${v}'") cfg.fel-env
        )}

        args=(
          uboot "${cfg.fel-firmware}"
          write "$scriptaddr"     "${fel-bootscr}"
          write "$kernel_addr_r"  "${kernel}/zImage"
          write "$fdt_addr_r"     "${kernel}/dtbs/${lib.head dtbFiles}"
          write "$ramdisk_addr_r" "${initramfs}"
        )

        set -x
        sunxi-fel -v -p "''${args[@]}"
      '';
    };
  };
}
