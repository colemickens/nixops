{ location ? "westus"
, nodeCount ? 3
, ...}:

with (import <nixpkgs> {}).lib;
let

  credentials = { };

  masterDef = { resources, config, pkgs, nodes, ...}: {
    deployment.targetEnv = "azure";

    deployment.azure = credentials // {
      location = "westus";
      size = "Standard_D3_v2";
      networkInterfaces.default.ip.allocationMethod = "Static";
    };

    networking.firewall.enable = false;

    # TODO. figure out where etcd should and shouldn't run
    # TODO. factor the systemPackages so they're not copy pasted

    environment.systemPackages = with pkgs; [ git gist neovim jq tmux ];
    virtualisation.docker = {
      enable = true;
      socketActivation = false;
    };
    services = {
      etcd = {
        listenClientUrls = [ "http://0.0.0.0:2379" ];
      };
      flannel = {
        enable = true;
        configureDocker = true;
        configureCidr = "10.2.0.0/16";
        etcdEndpoints = [ "http://127.0.0.1:2379" ];
      };
      kubernetes = {
        roles = [ "master" ];
        etcdServers = [ "127.0.0.1:2379" ];
        verbose = true;
        kubelet = {
          clusterDns = "10.3.0.10";
        };
        apiserver = {
          address = "0.0.0.0";
          portalNet = "10.3.0.0/16";
        };
      };
    };
  };

  nodeDef = { resources, config, pkgs, nodes, ...}: {
    deployment.targetEnv = "azure";

    deployment.azure = credentials // {
      location = "westus";
      size = "Standard_D3_v2";
    };

    networking.firewall.enable = false;

    environment.systemPackages = with pkgs; [ git gist neovim ];
    virtualisation.docker = {
      enable = true;
      socketActivation = false;
    };
    services = {
      flannel = {
        enable = true;
        configureDocker = true;
        etcdEndpoints = [ "http://${nodes.master.config.networking.privateIPv4}:2379" ];
      };
      kubernetes = {
        roles = [ "node" ];
        etcdServers = [ "${nodes.master.config.networking.privateIPv4}:2379" ];
        verbose = true;

        kubelet = {
          apiServers = [ "${nodes.master.config.networking.privateIPv4}:8080" ];
        };

        proxy = {
          master = "${nodes.master.config.networking.privateIPv4}:8080";
        };
      };
    };
  };

  mkNodes = builtins.listToAttrs (builtins.map (nodeid: {
      name = "node${toString nodeid}";
      value = nodeDef;
  }) (range 1 nodeCount));

in {
  "master" = masterDef;
} // mkNodes
