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
        # Browser build: odin-gb.wasm plus the JS host, ready to serve as-is.
        packages.web = pkgs.stdenv.mkDerivation {
          name = "odin-gb-web";
          src = ./.;
          nativeBuildInputs = [ pkgs.odin ];
          buildPhase = ''
            odin build src/web -target:js_wasm32 -out:odin-gb.wasm -o:speed
          '';
          installPhase = ''
            mkdir -p $out
            cp odin-gb.wasm $out/
            cp ${pkgs.odin}/share/core/sys/wasm/js/odin.js $out/
            cp web/index.html web/odin-gb.js web/audio-worklet.js $out/
          '';
        };

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
