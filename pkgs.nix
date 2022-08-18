let
  rev = "c4a0efdd5a728e20791b8d8d2f26f90ac228ee8d";
  sha256 = "0rg066r8hx882hlhi4yvz6d8nyww7cqbjknyrsk0w44jj2jzaidg";
in
import (
  builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
  }
)
