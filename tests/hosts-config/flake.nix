{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    let
      testing-utils = import ../testing-utils.nix { inherit (self.pkgs.x86_64-linux) nixpkgs; };
      inherit (testing-utils) hasKey base-nixos isEqual;
    in
    utils.lib.systemFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" ];

      channels.nixpkgs.input = nixpkgs;
      channels.unstable.input = nixpkgs;
      channels.someChannel.input = nixpkgs;



      #################
      ### Test Data ###
      #################

      # Hosts
      hostDefaults = {
        output = "someConfigurations";
        system = "aarch64-linux";
        channelName = "someChannel";
        extraArgs.sharedExtraArg = "sharedExtraArg";
        specialArgs.sharedSpecialArg = "sharedSpecialArg";

        modules = [
          base-nixos
          # Assigning to lib.* so we could assert these options in checks
          ({ sharedExtraArg, sharedSpecialArg, ... }: {
            lib = { inherit sharedExtraArg sharedSpecialArg; };
          })
        ];
      };

      hosts.Plain = { };

      hosts.WithFakeBuilder = {
        builder = args: { fakeBuilder = "fakeBuilder"; };
      };

      hosts.Customized = {
        output = "darwinConfigurations";
        system = "x86_64-darwin";
        channelName = "unstable";
        extraArgs.hostExtraArg = "hostExtraArg";
        specialArgs.hostSpecialArg = "hostSpecialArg";

        # Assigning to lib.* so we could assert these options in checks
        modules = [
          ({ hostExtraArg, hostSpecialArg, ... }: {
            lib = { inherit hostSpecialArg hostExtraArg; };
          })
        ];
      };



      ######################
      ### Test execution ###
      ######################

      outputsBuilder = channels: {
        checks =
          let
            plainHost = self.someConfigurations.Plain;
            plainHostPkgs = plainHost.config.nixpkgs.pkgs;

            customizedHost = self.darwinConfigurations.Customized;
            customizedHostPkgs = customizedHost.config.nixpkgs.pkgs;
          in
          {

            # Plain system with inherited options from hostDefaults
            system_valid_1 = isEqual plainHostPkgs.system "aarch64-linux";

            channelName_valid_1 = isEqual plainHostPkgs.name "someChannel";

            channelInput_valid_1 = hasKey plainHostPkgs "input";

            extraArgs_valid_1 = hasKey plainHost.config.lib "sharedExtraArg";

            specialArgs_valid_1 = hasKey plainHost.config.lib "sharedSpecialArg";


            # System with overwritten hostDefaults
            system_valid_2 = isEqual customizedHostPkgs.system "x86_64-darwin";

            channelName_valid_2 = isEqual customizedHostPkgs.name "unstable";

            channelInput_valid_2 = hasKey customizedHostPkgs "input";

            extraArgs_valid_2 = hasKey customizedHost.config.lib "hostExtraArg";

            specialArgs_valid_2 = hasKey customizedHost.config.lib "hostSpecialArg";


            # Eval fakeBuilder
            builder_applied = isEqual self.someConfigurations.WithFakeBuilder.fakeBuilder "fakeBuilder";

          };
      };

    };
}




