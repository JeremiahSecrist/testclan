{
  description = "<Put your description here>";

  inputs.clan-core.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
  inputs.nixpkgs.follows = "clan-core/nixpkgs";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

  outputs =
    inputs@{
      self,
      clan-core,
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      imports = [ inputs.clan-core.flakeModules.default ];
      # https://docs.clan.lol/getting-started/flake-parts/
      clan =
        let
          fs = nixpkgs.lib.fileset;
          nixosModules = fs.toList ./modules;
        in
        {
          meta.name = "testclan"; # Ensure this is unique among all clans you want to use.

          # Make flake available in modules
          specialArgs.self = {
            inherit (self) inputs nixosModules packages;
          };
          directory = self;
          machines = {
            # "jon" will be the hostname of the machine
            jon =
              { pkgs, ... }:
              {
                imports = nixosModules ++ [ ./machines/jon/configuration.nix ];

                nixpkgs.hostPlatform = "x86_64-linux";

                # Set this for clan commands use ssh i.e. `clan machines update`
                # If you change the hostname, you need to update this line to root@<new-hostname>
                # This only works however if you have avahi running on your admin machine else use IP
                clan.core.networking.targetHost = pkgs.lib.mkDefault "root@jon";

                # You can get your disk id by running the following command on the installer:
                # Replace <IP> with the IP of the installer printed on the screen or by running the `ip addr` command.
                # ssh root@<IP> lsblk --output NAME,ID-LINK,FSTYPE,SIZE,MOUNTPOINT
                disko.devices.disk.main = {
                  device = "/dev/disk/by-id/ata-QEMU_DVD-ROM_QM00003";
                };

                # IMPORTANT! Add your SSH key here
                # e.g. > cat ~/.ssh/id_ed25519.pub
                users.users.root.openssh.authorizedKeys.keys = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJAGm66rJsr8vjRCYDkH4lEPncPq27o6BHzpmRmkzOiM"
                  "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBA9i9HoP7X8Ufzz8rAaP7Nl3UOMZxQHMrsnA5aEQfpTyIQ1qW68jJ4jGK5V6Wv27MMc3czDU1qfFWIbGEWurUHQ="
                ];

                # Zerotier needs one controller to accept new nodes. Once accepted
                # the controller can be offline and routing still works.
                clan.core.networking.zerotier.controller.enable = true;
              };
          };
        };
      perSystem =
        { pkgs, inputs', ... }:
        {
          devShells.default = pkgs.mkShell { packages = [ inputs'.clan-core.packages.clan-cli ]; };
        };
    };
}
