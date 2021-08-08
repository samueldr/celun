#
# Quick way to eval a smolix system.
#
# *This is not an external interface*. Do not import this file from your
# project or configuration, as this may become opinionated in the future.
#
{ device ? null, configuration ? { } }@args:

import ./lib/eval-with-configuration.nix (args // {
  inherit device;
  verbose = true;
  configuration = {
    imports = [
      configuration
      (
        { lib, ... }:
        {
          smolix.system.automaticCross = lib.mkDefault true;
        }
      )
    ];
  };
})
