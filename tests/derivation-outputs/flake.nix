{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    let
      mkApp = utils.lib.mkApp;

      packagePname = drvKey: self.packages.x86_64-linux.${drvKey}.pname;

      appHasSuffix = drvKey: suffix: nixpkgs.lib.hasSuffix suffix self.apps.x86_64-linux.${drvKey}.program;

      defaultAppHasSuffix = suffix: nixpkgs.lib.hasSuffix suffix self.defaultApp.x86_64-linux.program;

      pnameFromOutput = output: self.${output}.x86_64-linux.pname;
    in
    utils.lib.systemFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" ];
      channels.nixpkgs.input = nixpkgs;



      #################
      ### Test Data ###
      #################

      defaultPackageBuilder = channels: channels.nixpkgs.coreutils;

      packagesBuilder = channels: {
        inherit (channels.nixpkgs) coreutils;
      };

      # Should Get merged with `packagesBuilder`
      packages.x86_64-linux.coreutils2 = self.pkgs.x86_64-linux.nixpkgs.coreutils;



      appsBuilder = channels: {
        coreutils = mkApp {
          drv = channels.nixpkgs.coreutils;
          exePath = "/bin/nice";
        };
      };


      defaultAppBuilder = channels: mkApp {
        drv = channels.nixpkgs.coreutils;
        exePath = "/bin/nice";
      };

      devShellBuilder = channels: channels.nixpkgs.mkShell {
        pname = "super-shell";
      };




      ######################
      ### Test execution ###
      ######################

      checksBuilder = channels:
        let
          isTrue = cond:
            if cond
            then channels.nixpkgs.runCommandNoCC "success" { } "echo success > $out"
            else channels.nixpkgs.runCommandNoCC "failure" { } "exit 1";
        in
        {

          # Packages
          defaultPackageValid = isTrue (pnameFromOutput "defaultPackage" == "coreutils");

          packagesValid = isTrue (packagePname "coreutils" == "coreutils");

          packagesMerged = isTrue (packagePname "coreutils2" == "coreutils");


          # Apps
          appsValid = isTrue (appHasSuffix "coreutils" "nice");

          defaultAppValid = isTrue (defaultAppHasSuffix "nice");

          # Devshell
          devshellValid = isTrue (pnameFromOutput "devShell" == "super-shell");

        };

    };
}




