{
  description = "VMWare Player";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";
  };

  outputs = { self, nixpkgs }:
  let
    version12 = "12.5.9";
    version16 = "16.2.3";
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
    kernel = nixpkgs.legacyPackages.x86_64-linux.pkgs.linux_5_15;

    bundle12 = pkgs.fetchurl {
      url = "http://127.0.0.1/public/VMware-Player-12.5.9-7535481.x86_64.bundle";
      sha256 = "2a967fe042c87b7a774ba1d5a7d63ee64f34b5220bf286370ca3439fed60487a";
    };

    bundle16 = pkgs.fetchurl {
      url = "http://127.0.0.1/public/VMware-Player-Full-16.2.3-19376536.x86_64.bundle";
      sha256 = "2c320084765b7a4cd79b6a0e834a6d315c4ecd61d0cc053aa7a445a7958738b0";
    };

    mkBundles = import ./bundle pkgs;
    vmware-bundle-12 = mkBundles.mkBundle12 version12 bundle12;
    vmware-bundle-16 = mkBundles.mkBundle16 version16 bundle16;

    mkVmxs = import ./vmx { inherit pkgs; };
    vmware-vmx-16 = mkVmxs.mkVmx16 version16 vmware-bundle-16;
    vmware-vmx-12 = mkVmxs.mkVmx12 version12 vmware-bundle-12;

    mkKernels = import ./vmware-kernel.nix (pkgs // { inherit kernel; });
    vmware-kernel-12 = mkKernels.mkKernel12 version12 vmware-bundle-12;
    vmware-kernel-16 = mkKernels.mkKernel16 version16 vmware-bundle-16;

    vmware-config-12 = import ./vmware-config.nix {
      stdenv = pkgs.stdenv;
      inherit kernel;
      vmware-vmx = vmware-vmx-12;
      vmware-kernel = vmware-kernel-12;
      version = version12;
    };

    vmware-config-16 = import ./vmware-config.nix {
      stdenv = pkgs.stdenv;
      inherit kernel;
      vmware-vmx = vmware-vmx-16;
      vmware-kernel = vmware-kernel-16;
      version = version16;
    };

    buildFHS = version: vmware-config: vmware-vmx: vmware-kernel:
      pkgs.buildFHSUserEnv {
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
    vmware-player-fhs12 = buildFHS version12 vmware-config-12 vmware-vmx-12 vmware-kernel-12;
    vmware-player-fhs16 = buildFHS version16 vmware-config-16 vmware-vmx-16 vmware-kernel-16;
  in
  {
    inherit vmware-bundle-16;
    inherit vmware-bundle-12;
    inherit vmware-vmx-16;
    inherit vmware-vmx-12;
    inherit vmware-kernel-16;
    inherit vmware-kernel-12;
    inherit vmware-player-fhs16;
    inherit vmware-player-fhs12;

    overlay = final: prev: {
      vmware-player-12 = vmware-player-fhs12;
      vmware-player-16 = vmware-player-fhs16;
      inherit vmware-bundle-16;
      inherit vmware-bundle-12;
      inherit vmware-vmx-16;
      inherit vmware-vmx-12;
      inherit vmware-kernel-16;
      inherit vmware-kernel-12;
    };
    defaultPackage.x86_64-linux = vmware-player-fhs16;
  };
}
