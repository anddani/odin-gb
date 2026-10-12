{
  description = "Odin development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            odin   # the Odin compiler
            ols    # Odin language server (editor integration)
            raylib # system raylib; vendor:raylib links against it
          ];

          shellHook = ''
            echo "Odin $(odin version)"
          '';
        };
      });
}
