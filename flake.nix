{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = inputs@{self, nixpkgs, ...}:
    let
      package = pkgs:
        pkgs.ocamlPackages.buildDunePackage {
          pname = "schemebot";
          version = "0.0.1";
          src = ./.;

          buildInputs = with pkgs.ocamlPackages; [findlib cohttp-lwt-unix yojson lwt];
        };
      shell = pkgs:
        pkgs.mkShell {
          inputsFrom = [(package pkgs)];
          nativeBuildInputs = [pkgs.ocamlPackages.merlin];
        };
    in
    {
      packages.x86_64-linux.default = package nixpkgs.legacyPackages.x86_64-linux;
      packages.aarch64-linux.default = package nixpkgs.legacyPackages.aarch64-linux;
      packages.aarch64-darwin.default = package nixpkgs.legacyPackages.aarch64-darwin;

      devShells.x86_64-linux.default = shell nixpkgs.legacyPackages.x86_64-linux;
      devShells.aarch64-linux.default = shell nixpkgs.legacyPackages.aarch64-linux;
      devShells.aarch64-darwin.default = shell nixpkgs.legacyPackages.aarch64-darwin;
      
    };
}
