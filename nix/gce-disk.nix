{ config, pkgs, uuid, name, ... }:

with pkgs.lib;

{

  options = {

    name = mkOption {
      example = "My Big Fat Disk";
      default = "nixops-${uuid}-${name}";
      type = types.str;
      description = "Description of the GCE disk.  This is the <literal>Name</literal> tag of the disk.";
    };

    region = mkOption {
      example = "europe-west1-b";
      type = types.str;
      description = "The GCE datacenter in which the disk should be created.";
    };

    serviceAccount = mkOption {
      default = "";
      example = "12345-asdf@developer.gserviceaccount.com";
      type = types.str;
      description = ''
        The GCE Service Account Email. If left empty, it defaults to the
        contents of the environment variable <envar>GCE_SERVICE_ACCOUNT</envar>.
      '';
    };

    accessKey = mkOption {
      default = "";
      example = "/path/to/secret/key.pem";
      type = types.str;
      description = ''
        The path to GCE Service Account key. If left empty, it defaults to the
        contents of the environment variable <envar>ACCESS_KEY_PATH</envar>.
      '';
    };

    project = mkOption {
      default = "";
      example = "myproject";
      type = types.str;
      description = ''
        The GCE project which should own the disk. If left empty, it defaults to the
        contents of the environment variable <envar>GCE_PROJECT</envar>.
      '';
    };

    size = mkOption {
      default = null;
      example = 100;
      type = types.nullOr types.int;
      description = ''
        Disk size (in gigabytes).  This may be left unset if you are
        creating the disk from a snapshot or image, in which case the
        size of the disk will be equal to the size of the snapshot or image.
        You can set a size larger than the snapshot or image,
        allowing the disk to be larger than the snapshot from which it is
        created.
      '';
    };

    snapshot = mkOption {
      default = null;
      example = "snap-1cbda474";
      type = types.nullOr types.str;
      description = ''
        The snapshot name from which this disk will be created. If
        not specified, an empty disk is created.  Changing the
        snapshot name has no effect if the disk already exists.
      '';
    };

    image = mkOption {
      default = null;
      example = "image-2cfda297";
      type = types.nullOr types.str;
      description = ''
        The image name from which this disk will be created. If
        not specified, an empty disk is created.  Changing the
        image name has no effect if the disk already exists.
      '';
    };

  };

  config = 
    (mkAssert ( (config.snapshot == null) || (config.image == null) )
              "Disk can not be created from both a snapshot and an image at once"
      (mkAssert ( (config.size != null) || (config.snapshot != null) || (config.image != null) )
                "Disk size is required unless it is created from an image or snapshot" {
          _type = "gce-disk";
        }
      )
    );

}