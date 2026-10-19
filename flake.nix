{
  description = "Prebuilt oh-my-pi (omp) binaries patched for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      source = builtins.fromJSON (builtins.readFile ./source.json);
      systems = builtins.attrNames source.assets;
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
      mkOmp =
        system: pkgs:
        pkgs.callPackage ./package.nix {
          inherit (source) version;
          src = pkgs.fetchurl {
            inherit (source.assets.${system}) url hash;
          };
        };
    in
    {
      packages = forAllSystems (
        system: pkgs:
        let
          omp = mkOmp system pkgs;
        in
        {
          inherit omp;
          default = omp;
        }
      );

      apps = forAllSystems (
        system: _: {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/omp";
            meta.description = "Run oh-my-pi";
          };
          omp = self.apps.${system}.default;
        }
      );

      overlays.default =
        final: prev:
        let
          system = final.stdenv.hostPlatform.system;
        in
        nixpkgs.lib.optionalAttrs (source.assets ? ${system}) {
          omp = mkOmp system final;
        };

      formatter = forAllSystems (_: pkgs: pkgs.nixfmt);
    };
}
