{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = inputs@{self, nixpkgs, ...}:
    let
      package = pkgs:
        pkgs.ocamlPackages.buildDunePackage {
          pname = "schemebot";
          version = "0.0.1";
          src = ./.;

          buildInputs = with pkgs.ocamlPackages; [findlib cohttp-lwt-unix yojson lwt tls-lwt];
        };
      musl = pkgs:
        package pkgs.pkgsMusl;
      container = pkgs:
        pkgs.dockerTools.streamLayeredImage {
          name = "turtyboi/schemebot";
          tag = "latest";

          contents = [
            (package pkgs)
            pkgs.chez
            pkgs.ghc
            pkgs.cacert
            pkgs.iana-etc
          ];
          config = {
            Cmd = ["${(package pkgs)}/bin/schemebot"];
            Env = [
              "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
              "PATH=${pkgs.chez}/bin:/bin"
              "PORT=8080"
            ];
            ExposedPorts = {
              "8080/tcp" = {};
            };
          };
        };
      shell = pkgs:
        pkgs.mkShell {
          inputsFrom = [(package pkgs)];
          nativeBuildInputs = [pkgs.ocamlPackages.merlin];
        };
    in
    {
      packages.x86_64-linux.default = package nixpkgs.legacyPackages.x86_64-linux;
      packages.x86_64-linux.musl = musl nixpkgs.legacyPackages.x86_64-linux;
      packages.x86_64-linux.container = container nixpkgs.legacyPackages.x86_64-linux;
      packages.aarch64-linux.default = package nixpkgs.legacyPackages.aarch64-linux;
      packages.aarch64-linux.musl = musl nixpkgs.legacyPackages.aarch64-linux;
      packages.aarch64-linux.container = container nixpkgs.legacyPackages.aarch64-linux;
      packages.aarch64-darwin.default = package nixpkgs.legacyPackages.aarch64-darwin;

      devShells.x86_64-linux.default = shell nixpkgs.legacyPackages.x86_64-linux;
      devShells.aarch64-linux.default = shell nixpkgs.legacyPackages.aarch64-linux;
      devShells.aarch64-darwin.default = shell nixpkgs.legacyPackages.aarch64-darwin;
      
    };
}
