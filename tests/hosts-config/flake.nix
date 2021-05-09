{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    let
      testing-utils = import ../testing-utils.nix { inherit (self.pkgs.x86_64-linux) nixpkgs; };
      inherit (testing-utils) hasKey base-nixos isEqual;
    in
    utils.lib.systemFlake {
      inherit self inputs;
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" ];

      channels.nixpkgs.input = nixpkgs;
      channels.unstable.input = nixpkgs;



      #################
      ### Test Data ###
      #################

      # Hosts
      hostDefaults.modules = [ base-nixos ];

      hosts.HostDefaults = { };

      hosts.Customized = {
        output = "darwinConfigurations";

        #builder = args: nix-darwin.lib.darwinSystem (builtins.removeAttrs args [ "system" ]);

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

      checksBuilder = channels:
        let
          customizedHost = self.darwinConfigurations.Customized;
          customizedHostPkgs = customizedHost.config.nixpkgs.pkgs;
        in
        {

          output_valid_1 = hasKey self.darwinConfigurations "Customized";

          system_valid_1 = isEqual customizedHostPkgs.system "x86_64-darwin";

          channelName_valid_1 = isEqual customizedHostPkgs.name "unstable";

          channelInput_valid_1 = hasKey customizedHostPkgs "input";

          extraArgs_valid_1 = hasKey customizedHost.config.lib "hostExtraArg";

          specialArgs_valid_1 = hasKey customizedHost.config.lib "hostSpecialArg";



        };

    };
}




