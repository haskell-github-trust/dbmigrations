{
  description = "Relational database migrations modeled as a directed acyclic graph";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: let
    pkg-name = "dbmigrations"; 
    haskell-overlay = pkgs: hfinal: hprev: let
      dontCheck = pkg: pkgs.haskell.lib.dontCheck pkg;
    in {
      ${pkg-name} = dontCheck (hfinal.callCabal2nixWithOptions pkg-name ./. "-f sqlite -f postgresql" {});
    };

    overlay = final: prev: {
      haskellPackages = prev.haskellPackages.extend (haskell-overlay final);
      dbm-postgresql = "${final.haskellPackages.dbmigrations}/bin/dbm-postgresql";
      dbm-sqlite = "${final.haskellPackages.dbmigrations}/bin/dbm-sqlite";
    };
  in
    {
      overlays = {
        default = overlay;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [overlay];
        };

        hspkgs = pkgs.haskellPackages;
      in {
        packages = {
          ${pkg-name} = hspkgs.${pkg-name};
          default = self.packages.${system}.${pkg-name};
        };

        devShells = {
          default = hspkgs.shellFor {
            packages = _: [self.packages.${system}.${pkg-name}];
            buildInputs = [
              pkgs.cabal-install
              pkgs.dbm-sqlite
              hspkgs.ormolu
            ];
            withHoogle = true;
            inputsFrom = builtins.attrValues self.packages.${system};
          };
        };

        formatter = pkgs.alejandra;
      }
    );
}
