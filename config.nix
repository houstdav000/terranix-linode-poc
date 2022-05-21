{ lib, outputs, ... }:

let
  region = "us-southeast";
in
{
  variable.LINODE_TOKEN = {
    type = "string";
    description = "Linode API token";
    nullable = false;
    sensitive = true;
  };

  terraform.required_providers.linode.source = "linode/linode";

  provider.linode.token = "\${ var.LINODE_TOKEN }";

  resource.linode_image.nixos =
  let
    img_dir = outputs.packages.x86_64-linux.linode;
    img = builtins.elemAt (lib.mapAttrsToList (name: _: img_dir + "/${name}") (builtins.readDir img_dir)) 0;
  in {
    inherit region;

    label = "nixos-test-image";
    description = "Image generated by nixos-generator";

    # Hash also acheived by using nix store, since hash is in path :P
    file_path = img;
  };

  resource.linode_instance.nixos-test =
    let
      bootLabel = "boot";
      swapLabel = "swap";
    in
    {
    inherit region;

    label = "nixos-test";
    group = "nixos";
    tags = [ "nixos" "test-instances" ];
    type = "g6-nanode-1";


    disk = [
      {
        label = bootLabel;
        size = 3000; # Integer size in MB. Can't configure with a dynamic var due to type limitations. Kinda a Terranix oversight I guess.
        image = "\${linode_image.nixos.id}";
      }
      {
        label = swapLabel;
        size = 512; # Integer size in MB.
        filesystem = "swap";
      }
    ];

    config = {
      label = "boot_config";

      # Found in https://api.linode.com/v4/linode/kernels?page=4
      kernel = "linode/grub2";

      # Had to pull from https://github.com/linode/terraform-provider-linode/blob/f8b80a1322d4f5afb24bfb318d216d4a2d630c27/linode/instance/schema_resource.go#L437
      helpers = {
        "updatedb_disabled" = false;
        "distro" = false;
        "modules_dep" = false;
        "network" = false;
        "devtmpfs_automount" = false;
      };

      root_device = "/dev/sda";

      devices = {
        sda.disk_label = bootLabel;
        sdb.disk_label = swapLabel;
      };

      interface = [
        {
          purpose = "public";
        }
      ];
    };
  };
}
