{
  description = "Kitchen Datasheet website";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };


  outputs = { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in
    {

      # apps = forAllSystems
      #   (system:
      #     let
      #       pkgs = nixpkgsFor.${system};
      #       servescript = pkgs.writeShellScriptBin "serve" ''
      #         export CMD_DRAW_HEADTABLE="${self.packages.${system}.generate-headtable}/bin/generate-headtable"
      #         export CMD_DRAW_NUTRIENTS="${self.packages.${system}.generate-nutrients}/bin/generate-nutrients"
      #         export PATH=$PATH:${pkgs.mdbook-cmdrun}/bin
      #         echo "Using $CMD_DRAW_HEADTABLE and $CMD_DRAW_NUTRIENTS as generators"
      #         ${pkgs.mdbook}/bin/mdbook serve --open
      #       '';
      #     in
      #     {
      #       default = {
      #         type = "app";
      #         program = "${servescript}/bin/serve";
      #       };
      #     }
      #   );

      packages = forAllSystems
        (system:
          let
            pkgs = nixpkgsFor.${system};

            vendorSha256 = "sha256-ZavlAFfHshXDdIq7uyNMtdJS4hmVil4ZdipF0pXnIRU=";

            ldflags = [
              "-s"
              "-w"
              "-X github.com/woodpecker-ci/woodpecker/version.Version=${version}"
            ];


            postBuild = ''
              cd $GOPATH/bin
              for f in *; do
                mv -- "$f" "woodpecker-$f"
              done
              cd -
            '';
          in
          rec {
            # bash-example = pkgs.writeShellScriptBin "example-script" ''
            #   echo test
            # '';

            # book = pkgs.stdenv.mkDerivation {

            #   name = "book";
            #   src = ./.;
            #   buildPhase = null;

            #   CMD_DRAW_HEADTABLE = "${self.packages.${system}.generate-headtable}/bin/generate-headtable";
            #   CMD_DRAW_NUTRIENTS = "${self.packages.${system}.generate-nutrients}/bin/generate-nutrients";

            #   installPhase = ''
            #     runHook preInstall
            #     mdbook build -d $out
            #     runHook postInstall
            #   '';

            #   buildInputs = [ pkgs.mdbook pkgs.mdbook-cmdrun ];

            #   meta = with pkgs.lib; {
            #     homepage = "TODO";
            #     description = "TODO";
            #     license = licenses.mit;
            #     maintainers = [ maintainers.pinpox ];
            #   };

            # };


            # { lib, buildGoModule, callPackage, fetchFromGitHub, pkgs, inputs }:

            woodpecker-frontend =
              let
                nodePackages =
                  let nodejs = pkgs.nodejs;

                  in
                  import ./node-composition.nix {
                    inherit pkgs nodejs;
                    inherit (pkgs.stdenv.hostPlatform) system;
                  };
              in
              pkgs.stdenv.mkDerivation

                {
                  name = "woodpecker-frontend";

                  src = ./web;


                  nativeBuildInputs = [
                    pkgs.nodejs
                  ];

                  buildPhase =
                    let
                      nodeDependencies = ((import ./node-composition.nix {
                        inherit pkgs; # nodejs;
                        inherit (pkgs.stdenv.hostPlatform) system;
                      }).nodeDependencies.override (old: {
                        src = ./web;

                        # dont run the prepare script:
                        # npm run build:production runs the same command
                        # dontNpmInstall = true;
                      }));
                    in
                    ''
                      runHook preBuild
                      ln -s ${nodeDependencies}/lib/node_modules ./node_modules
                      export PATH="${nodeDependencies}/bin:$PATH"
                      npm run build
                      runHook postBuild
                    '';

                  installPhase = ''
                    runHook preInstall
                    mkdir -p $out
                    cp -a dist/* $out
                    runHook postInstall
                  '';
                };

            woodpecker-server =
              pkgs.buildGoModule {
                name = "woodpecker-server";
                inherit vendorSha256 ldflags postBuild;
                src = ./.;

                postPatch = ''
                  cp -r ${woodpecker-frontend} web/dist
                '';

                subPackages = "cmd/server";
                CGO_ENABLED = 1;
                passthru = { inherit woodpecker-frontend; };
              };


            woodpecker-agent = pkgs.buildGoModule {
              name = "woodpecker-agent";
              src = ./.;
              inherit vendorSha256 ldflags postBuild;
              subPackages = "cmd/agent";
              CGO_ENABLED = 0;
            };

          });

      # defaultPackage = forAllSystems (system: self.packages.${system}.book);
    };
}
