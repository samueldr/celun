{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkDefault
    mkMerge
  ;

  u-boot = pkgs.callPackage (
    { buildUBoot, fetchFromGitHub }:

    (buildUBoot {
      version = "2022.07-rc5";
      # Some fixes and hack reverts compared to the vendor provided repo
      # https://github.com/PopcornComputer/Popstick-uboot
      src = fetchFromGitHub {
        owner = "samueldr";
        repo = "u-boot";
        rev = "7887fe0d00672ff8f2c482ec10c93eeaacd16d6e"; # wip/sourceparts-popstick
        sha256 = "sha256-CJBKbvbuX7a4kj66EppXjV5lexcaewKwQsOYhHAxkf8=";
      };
      defconfig = "popstick_defconfig"; 
      extraMeta.platforms = ["armv5tel-linux"];         
      filesToInstall = ["u-boot-sunxi-with-spl.bin"];  
    }).overrideAttrs({ ... }: {
      patches = [];
    })
  ) { };
in
{
  device = {
    name = "sourceparts/popstick";
    dtbFiles = [
      "suniv-f1c200s-popstick-v1.1.dtb"
    ];
    config.allwinner = {
      embedFirmware = true;
      firmwarePartition = "${u-boot}/u-boot-sunxi-with-spl.bin";

      # Unclear whether this is an allwinner-wide bug, or f1c100s only...
      # But FEL-booted systems don't see the environment set by the FEL tool.
      # NOTE: it's assumed that we'll use FEL only with mainline U-Boot...
      #       this is not the expected way to run anything really.
      fel-firmware = (u-boot.overrideAttrs({preConfigure ? "", ...}: {
        preConfigure = preConfigure + ''
          cat <<EOF >> configs/popstick_defconfig
          CONFIG_BOOTCOMMAND="source \''${scriptaddr}"
          EOF
        '';
      })) + "/u-boot-sunxi-with-spl.bin";
    };
  };

  hardware = {
    cpu = "allwinner-f1c200s";
  };

  wip.kernel.package = pkgs.callPackage (
    { stdenv, fetchFromGitHub }:

    # NOTE: this is only used to borrow some arguments at this point in time.
    stdenv.mkDerivation {
      version = "6.0.0";
      # Source Parts have only published the changes as patches for now.
      # This repo collects them together without additional changes.
      src = fetchFromGitHub {
        owner = "samueldr";
        repo = "linux";
        rev = "3f5b0a5d6d711db589c567ef9ce0536e9ccab52e"; # wip/sourceparts-popstick
        sha256 = "sha256-xtA2VYmS4GOjznWefc4Y42z/nlFup71rO6SAeq3QTSo=";
      };
    }
  ) { };

  wip.kernel.defconfig = pkgs.writeText "empty" "";

  wip.kernel.features = {
    graphics = false;
    logo = false;
    vt = false;
  };

  wip.kernel.structuredConfig =
    with lib.kernel;
    let
      inherit (config.wip.kernel) features;
    in
    mkMerge [
      {
        ARCH_SUNXI = yes;
        VFP = yes;
        ARCH_MULTI_V7 = no;
        ARM_MODULE_PLTS = no;
        ATAGS = no;
        SUSPEND = no;
        DMADEVICES = yes;
        SERIO = no;
        HW_RANDOM = no;
        RANDOM_TRUST_BOOTLOADER = no;
        RTC_CLASS = no;
        IOMMU_SUPPORT = no;
        HWMON = no;
        POWER_SUPPLY = yes;
        WATCHDOG = yes;
        SUNXI_WATCHDOG = yes;
        MFD_SUN6I_PRCM = yes;
        REGULATOR = yes;
        REGULATOR_FIXED_VOLTAGE = yes;
        REGULATOR_GPIO = yes;
        PWM = yes;
        PWM_SUN4I = yes;
        SPI = yes;
        SPI_SUN6I = yes;
        I2C = yes;
        I2C_MV64XXX = yes;
      }

      # TODO USB/gadget feature
      {
        USB = yes;
        USB_MUSB_HDRC = yes;
        USB_MUSB_SUNXI = yes;
        PHY_SUN4I_USB = yes;
        NOP_USB_XCEIV = yes;
      }

      # TODO mtd support
      {
        MTD = yes;
        MTD_CMDLINE_PARTS = yes;
        MTD_BLOCK = yes;
        MTD_SPI_NAND = yes;
        MTD_SPI_NOR = yes;
      }

      # TODO mmc support
      {
        MMC = yes;
        PWRSEQ_EMMC = yes;
        PWRSEQ_SIMPLE = yes;
        MMC_SUNXI = yes;
      }

      {
        # XXX Add to F1CX00S ?
        SERIAL_8250 = yes;
        SERIAL_8250_CONSOLE = yes;
        SERIAL_8250_NR_UARTS = freeform ''8'';
        SERIAL_8250_RUNTIME_UARTS = freeform ''8'';
        SERIAL_8250_DW = yes;
        SERIAL_OF_PLATFORM = yes;
      }

      # Features that don't make sense on this device.
      {
        # No network interface
        ETHERNET = mkDefault no;
        # No input
        KEYBOARD_ATKBD = mkDefault no;
        INPUT_MOUSE = mkDefault no;
        INPUT_TOUCHSCREEN = mkDefault no;
        RC_CORE = mkDefault no;
        MEDIA_CEC_SUPPORT = mkDefault no;
        # No display
        DRM = mkDefault no;
        FB = mkDefault no;
        MEDIA_SUPPORT = mkDefault no;
        BACKLIGHT_CLASS_DEVICE = mkDefault no;
        LOGO = mkDefault no;
        FB_TFT = mkDefault no;
        # No sound
        SOUND = mkDefault no;
      }

      {
        # XXX figure out why they end-up being enabled
        VT = option no;
        VT_CONSOLE = option no;
      }
    ]
  ;
}
