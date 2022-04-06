{
  description = "VMWare Player";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
    kernel = nixpkgs.legacyPackages.x86_64-linux.pkgs.linux_5_15;

    mkBundles = import ./bundle pkgs;
    mkVmxs = import ./vmx { inherit pkgs; };
    mkKernels = import ./vmware-kernel.nix (pkgs // { inherit kernel; });

    mkVmwarePlayer = {version, bundle, mkBundle, mkVmx, mkKernel}: rec {
      vmware-bundle = mkBundle version bundle;
      vmware-vmx = mkVmx version vmware-bundle;
      vmware-kernel = mkKernel version vmware-bundle;
      vmware-config  = import ./vmware-config.nix {
        stdenv = pkgs.stdenv;
        inherit kernel;
        inherit vmware-vmx;
        inherit vmware-kernel;
        inherit version;
      };
      fhs = pkgs.buildFHSUserEnv {
        name = "vmware-player-fhs-${version}";

        targetPkgs = pkgs: with self.pkgs; [
          vmware-config
          vmware-vmx
          vmware-kernel
        ];
        profile = ''
          export VMWARE_VMX=${vmware-vmx}
          export VMWARE_CONFIG=${vmware-config}
          export VMWARE_KERNEL=${vmware-kernel}
        '';
        extraBuildCommands = ''
        '';
        extraInstallCommands = ''
        '';
        runScript = "bash -l";
      };
    };

    vmware-player-12 = mkVmwarePlayer {
      version = "12.5.9";
      bundle = pkgs.fetchurl {
        url = "http://127.0.0.1/public/VMware-Player-12.5.9-7535481.x86_64.bundle";
        sha256 = "2a967fe042c87b7a774ba1d5a7d63ee64f34b5220bf286370ca3439fed60487a";
      };
      mkBundle = mkBundles.mkBundle12;
      mkVmx = mkVmxs.mkVmx12;
      mkKernel = mkKernels.mkKernel12;
    };

    vmware-player-16 = mkVmwarePlayer {
      version = "16.2.3";
      bundle = pkgs.fetchurl {
        url = "http://127.0.0.1/public/VMware-Player-Full-16.2.3-19376536.x86_64.bundle";
        sha256 = "2c320084765b7a4cd79b6a0e834a6d315c4ecd61d0cc053aa7a445a7958738b0";
      };
      mkBundle = mkBundles.mkBundle16;
      mkVmx = mkVmxs.mkVmx16;
      mkKernel = mkKernels.mkKernel16;
    };
  in
  {
    inherit vmware-player-12;
    inherit vmware-player-16;

    overlay = final: prev: {
      vmware-player-12 = vmware-player-12.fhs;
      vmware-player-16 = vmware-player-16.fhs;
    };
    defaultPackage.x86_64-linux = vmware-player-16.fhs;
  };
}
