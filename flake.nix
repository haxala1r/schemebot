{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = inputs@{self, nixpkgs, ...}:
    let
      package = pkgs:
        pkgs.ocamlPackages.buildDunePackage {
          pname = "schemebot";
          version = "0.0.1";
          src = ./.;

          buildInputs = with pkgs.ocamlPackages; [];
        };
    in
    {
      packages.x86_64-linux.default = package nixpkgs.legacyPackages.x86_64-linux;
      packages.aarc64-linux.default = package nixpkgs.legacyPackages.aarch64-linux;
      packages.aarch64-darwin.default = package nixpkgs.legacyPackages.aarch64-darwin;
    };
}
