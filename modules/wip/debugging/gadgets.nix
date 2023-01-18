{ config, lib, ... }:

let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
  ;
  cfg = config.wip.debugging.gadgets;
in
{
  options = {
    wip.debugging.gadgets = {
      enablePrecomposedSerial = mkOption {
        description = ''
          Enable usage of the legacy pre-composed serial USB gadget.

          The device will need to configure the basic device-specific
          gadget options.

          Do not rely on this option for final systems. It is
          preferrable to use the functions configurable gadgets.
          Use only as a debugging aid.

          This option enables use of a serial console without needing
          a userspace component to configure the gadget. It is also
          possible to use the added console (`ttyGS0`) as a kernel
          console, though it will miss early boot messages.
        '';
        default = false;
        type = types.bool;
      };
      enablePrecomposedNetworking = mkOption {
        description = ''
          Enable usage of a pre-composed network USB gadget.

          Do not rely on this option for final systems. It is
          preferrable to use the functions configurable gadgets.
          Use only as a debugging aid.

          The networking device will be left to be configured
          by other modules.
        '';
        default = false;
        type = types.bool;
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.enablePrecomposedSerial) {
      wip.kernel.structuredConfig = with lib.kernel; {
        USB_GADGET = yes;
        USB_G_SERIAL = yes;
        USB_CONFIGFS = yes;
        USB_CONFIGFS_SERIAL = yes;
        # Allow using the pre-composed serial gadget as the console
        U_SERIAL_CONSOLE = yes;
      };
    })
    (mkIf (cfg.enablePrecomposedNetworking) {
      wip.kernel.structuredConfig = with lib.kernel; {
        USB_GADGET = yes;
        USB_CDC_COMPOSITE = yes;
        TTY = yes;
        NET = yes;
        USB_CONFIGFS = yes;
        USB_CONFIGFS_ECM = yes;
      };
    })
  ];

}
