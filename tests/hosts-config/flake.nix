{
  inputs.utils.url = path:../../;

  outputs = inputs@{ self, nixpkgs, utils }:
    let
      base-nixos = {
        boot.loader.grub.devices = [ "nodev" ];
        fileSystems."/" = { device = "test"; fsType = "ext4"; };
      };
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

      hosts."com.example.myhost" = { };

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
            inherit (utils.lib.check-utils channels.nixpkgs) hasKey isEqual;

            plainHost = self.someConfigurations.Plain;
            plainHostPkgs = plainHost.config.nixpkgs.pkgs;
            plainHostName = plainHost.config.networking.hostName;
            plainHostDomain = plainHost.config.networking.domain;

            reverseDnsHost = self.someConfigurations."com.example.myhost";
            reverseDnsHostName = reverseDnsHost.config.networking.hostName;
            reverseDnsHostDomain = reverseDnsHost.config.networking.domain;

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

            hostName_valid_1 = isEqual plainHostName "Plain";

            domain_valid_1 = isEqual plainHostDomain null;


            # System with overwritten hostDefaults
            system_valid_2 = isEqual customizedHostPkgs.system "x86_64-darwin";

            channelName_valid_2 = isEqual customizedHostPkgs.name "unstable";

            channelInput_valid_2 = hasKey customizedHostPkgs "input";

            extraArgs_valid_2 = hasKey customizedHost.config.lib "hostExtraArg";

            specialArgs_valid_2 = hasKey customizedHost.config.lib "hostSpecialArg";


            # Hostname and Domain set from reverse DNS name
            hostName_valid_3 = isEqual reverseDnsHostName "myhost";

            domain_valid_3 = isEqual reverseDnsHostDomain "example.com";


            # Eval fakeBuilder
            builder_applied = isEqual self.someConfigurations.WithFakeBuilder.fakeBuilder "fakeBuilder";

          };
      };

    };
}




