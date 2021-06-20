{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    let
      mkApp = utils.lib.mkApp;
    in
    utils.lib.systemFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" ];
      channels.nixpkgs.input = nixpkgs;


      #################
      ### Test Data ###
      #################


      # Should Get merged with `packagesBuilder`
      packages.x86_64-linux.coreutils2 = self.pkgs.x86_64-linux.nixpkgs.coreutils;

      outputsBuilder = channels: {

        packages = {
          inherit (channels.nixpkgs) coreutils;
        };

        defaultPackage = channels.nixpkgs.coreutils;

        apps = {
          coreutils = mkApp {
            drv = channels.nixpkgs.coreutils;
            exePath = "/bin/nice";
          };
        };


        defaultApp = mkApp {
          drv = channels.nixpkgs.coreutils;
          exePath = "/bin/nice";
        };

        devShell = channels.nixpkgs.mkShell {
          pname = "super-shell";
        };



        ######################
        ### Test execution ###
        ######################

        checks =
          let
            inherit (utils.lib.check-utils channels.nixpkgs) hasKey isEqual;
            inherit (nixpkgs.lib) hasSuffix;
            getOutput = output: self.${output}.${channels.nixpkgs.system};

            packages = getOutput "packages";
            defaultPackage = getOutput "defaultPackage";
            devShell = getOutput "devShell";

            isTrue = cond:
              if cond
              then channels.nixpkgs.runCommandNoCC "success" { } "echo success > $out"
              else channels.nixpkgs.runCommandNoCC "failure" { } "exit 1";
          in
          {

            # Packages
            defaultPackage_valid = isEqual defaultPackage.pname "coreutils";

            packages_valid = isEqual packages.coreutils.pname "coreutils";
            packages_merged = isEqual packages.coreutils2.pname "coreutils";


            # Apps
            apps_valid = isTrue (hasSuffix "nice" (getOutput "apps").coreutils.program);

            defaultApp_valid = isTrue (hasSuffix "nice" (getOutput "defaultApp").program);

            # Devshell
            devshell_valid = isEqual devShell.pname "super-shell";

          };

      };

    };
}

