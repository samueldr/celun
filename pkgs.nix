let
  rev = "18b14a254dca6b68ca0ce2ce885ce2b550065799";
  sha256 = "05npkk8hqa1x47xhzs9cdhsp0mlyhrav203dbfrg2jc9dq04rqyc";
in
import (
  builtins.fetchTarball {
    inherit sha256;
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
  }
)
