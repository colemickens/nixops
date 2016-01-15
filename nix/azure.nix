# Configuration specific to the Azure backend.

{ config, pkgs, lib, name, uuid, resources, ... }:

with lib;
with (import ./lib.nix lib);
let

  luksName = def: def.name;

  mkDefaultEphemeralName = mountPoint: cfg:
    cfg // (
      if cfg.name == null
      then {
          name = replaceChars ["/" "." "_"] ["-" "-" "-"]
                    (substring 1 ((stringLength mountPoint) - 1) mountPoint); }
      else {});

  azureDiskOptions = { config, ... }: {

    options = {

      name = mkOption {
        default = null;
        example = "data";
        type = types.nullOr types.str;
        description = "The short name of the disk to create.";
      };

      isEphemeral = mkOption {
        default = true;
        example = false;
        type = types.bool;
        description = ''
          Whether the disk is ephemeral. Emphemeral disk BLOBs
          are automatically created and destroyed by NixOps as needed. The user
          has an option to keep the BLOB with contents after the virtual machine
          is destroyed.
          Ephemeral disk names need to be unique only among the other ephemeral
          disks of the virtual machine.
        '';
      };

      mediaLink = mkOption {
        default = null;
        example = "http://mystorage.blob.core.windows.net/mycontainer/machine-disk";
        type = types.nullOr types.str;
        description = ''
          The location of the BLOB in the Azure BLOB store to store the ephemeral disk contents.
          The BLOB location must belong to a storage account in the same subscription
          as the virtual machine.
          If the BLOB doesn't exist, it will be created.
        '';
      };

      size = mkOption {
        default = null;
        type = types.nullOr types.int;
        description = ''
          Volume size (in gigabytes) for automatically created
          Azure disks. This option value is ignored if the
          disk BLOB already exists.
        '';
      };

      lun = mkOption {
        default = null;
        type = types.nullOr types.int;
        description = ''
          Logical Unit Number (LUN) location for the data disk
          in the virtual machine. Required if the disk is created
          via fileSystems.X.azure attrset. The disk will appear
          as /dev/disk/by-lun/*. Must be unique.
          Valid values are: 0-31.
          LUN value must be less than the maximum number of
          allowed disks for the virtual machine size.
        '';
      };

      hostCaching = mkOption {
        default = "None";
        type = types.addCheck types.str
                (v: elem v [ "None" "ReadOnly" "ReadWrite" ]);
        description = ''
          Specifies the platform caching behavior of data disk blob for
          read/write efficiency. The default vault is None.
          Possible values are: None, ReadOnly, ReadWrite.
        '';
      };

      # FIXME: remove the LUKS options eventually?

      encrypt = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether the Azure disk should be encrypted using LUKS.
        '';
      };

      cipher = mkOption {
        default = "aes-cbc-essiv:sha256";
        type = types.str;
        description = ''
          The cipher used to encrypt the disk.
        '';
      };

      keySize = mkOption {
        default = 128;
        type = types.int;
        description = ''
          The size of the encryption key.
        '';
      };

      passphrase = mkOption {
        default = "";
        type = types.str;
        description = ''
          The passphrase (key file) used to decrypt the key to access
          the device.  If left empty, a passphrase is generated
          automatically; this passphrase is lost when you destroy the
          machine or remove the volume, unless you copy it from
          NixOps's state file.  Note that the passphrase is stored in
          the Nix store of the instance, so an attacker who gains
          access to the Azure disk or instance store that contains the
          Nix store can subsequently decrypt the encrypted volume.
        '';
      };

    };

    config = {};
  };

in
{
  ###### interface

  options = {

    deployment.azure = (import ./azure-mgmt-credentials.nix lib "instance") // {

      machineName = mkOption {
        default = "nixops-${uuid}-${name}";
        example = "custom-machine-name";
        type = types.str;
        description = "The Azure machine <literal>Name</literal>.";
      };

      location = mkOption {
        example = "westus";
        type = types.str;
        description = "The Azure data center location where the virtual machine should be created.";
      };

      size = mkOption {
        default = "Basic_A0";
        example = "Standard_A0";
        type = types.str;
        description = "The size of the virtual machine to allocate.";
      };

      storage = mkOption {
        example = "resources.azureStorages.mystorage";
        type = types.either types.str (resource "azure-storage");
        description = ''
          Azure storage service name or resource to use to manage
          the disk BLOBs.
        '';
      };

      networkInterfaces.default = {
        subnet.network = mkOption {
          example = "resources.azureVirtualNetworks.mynetwork";
          type = types.either types.str (resource "azure-virtual-network");
          description = ''
            The Azure Resource Id or NixOps resource of
            the Azure virtual network to attach the network interface to.
          '';
        };

        subnet.name = mkOption {
          default = "default";
          example = "my-subnet";
          type = types.str;
          description = ''
            Azure virtual subnetwork name to attach the network interface to.
          '';
        };

        backendAddressPools = mkOption {
          default = [];
          example = [ {
            name = "website";
            loadBalancer = "resources.azureLoadBalancers.mybalancer";
          } ];
          type = types.listOf types.optionSet;
          description = "List of Azure load balancer backend address pools to join.";
          options = { config, ... }: {
            options = {
              loadBalancer = mkOption {
                example = "resources.azureLoadBalancers.mybalancer";
                type = types.either types.str (resource "azure-load-balancer");
                description = ''
                  The Azure Resource Id or NixOps resource of
                  the Azure load balancer to attach the interface to.
                '';
              };

              name = mkOption {
                default = "default";
                example = "website";
                description = ''
                  The name of the Azure load balancer Backend Address Pool to join.
                '';
              };
            };
            config = {};
          };
        };

        obtainIP = mkOption {
          default = false;
          example = true;
          type = types.bool;
          description = ''
            Whether to obtain a dedicated public IP for the interface.
          '';
        };
      };

      resourceGroup = mkOption {
        example = "resources.azureResourceGroups.mygroup";
        type = types.either types.str (resource "azure-resource-group");
        description = ''
          Azure resource group name or resource to create the machine in.
        '';
      };

      rootDiskImageUrl = mkOption {
        example = "nixos-bootstrap-30GB";
        type = types.str;
        description = ''
          Bootstrap image BLOB URL. Must reside on the same storage as VM disks.
        '';
      };

      baseEphemeralDiskUrl = mkOption {
        default = null;
        example = "http://mystorage.blob.core.windows.net/mycontainer/";
        type = types.nullOr types.str;
        description = ''
          Base URL to use to construct BLOB URLs for ephemeral disks which
          don't explicitly specify mediaLink.
        '';
      };

      blockDeviceMapping = mkOption {
        default = { };
        example = { "/dev/disk/by-lun/1".mediaLink =
                        "http://mystorage.blob.core.windows.net/mycontainer/machine-disk"; };
        type = types.attrsOf types.optionSet;
        options = azureDiskOptions;
        description = ''
          Block device mapping.
        '';
      };

      availabilitySet = mkOption {
        default = null;
        example = "resources.azureVirtualNetworks.myset";
        type = types.nullOr (types.either types.str (resource "azure-availability-set"));
        description = ''
          The Azure Resource Id or NixOps resource of
          the Azure availability set to place the machine into.
          Azure Virtual Machines specified in the same availability set
          are allocated to different hardware nodes to maximize availability.
        '';
      };

    };

    fileSystems = mkOption {
      options = { config, ... }: {
        options = {
          azure = mkOption {
            default = null;
            type = types.uniq (types.nullOr types.optionSet);
            options = azureDiskOptions;
            description = ''
              Azure disk to be attached to this mount point.  This is
              a shorthand for defining a separate
              <option>deployment.azure.blockDeviceMapping</option>
              attribute.
            '';
          };
        };
        config = mkIf(config.azure != null) {
          device = mkDefault (
              if config.azure.encrypt then "/dev/mapper/${luksName (mkDefaultEphemeralName config.mountPoint config.azure)}"
                                      else "/dev/disk/by-lun/${toString config.azure.lun}"
            );
        };
      };
    };

  };

  ###### implementation

  config = mkIf (config.deployment.targetEnv == "azure") {
    nixpkgs.system = mkOverride 900 "x86_64-linux";

    deployment.azure.blockDeviceMapping = {
      "/dev/sda" = {
        name = "root";
        hostCaching = "ReadWrite";
      };
    } // (listToAttrs
      (map (fs: let fsazure = mkDefaultEphemeralName fs.mountPoint fs.azure; in
                nameValuePair "/dev/disk/by-lun/${toString fs.azure.lun}" fsazure
        )
       (filter (fs: fs.azure != null) (attrValues config.fileSystems))));


    deployment.autoLuks =
      let
        f = dev: definition: nameValuePair
          ( luksName definition)
          { device = dev;
            autoFormat = true;
            inherit (definition) cipher keySize passphrase;
          };
      in mapAttrs' f (filterAttrs (name: dev: dev.encrypt) config.deployment.azure.blockDeviceMapping);


  };
}
