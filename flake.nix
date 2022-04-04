{
  description = "VMWare Player";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";
  };

  outputs = { self, nixpkgs }:
  let
    version = "16.2.3";
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
    kernel = nixpkgs.legacyPackages.x86_64-linux.pkgs.linux_5_15;

    bundle = pkgs.fetchurl {
      #url = "http://127.0.0.1/public/VMware-Player-12.5.9-7535481.x86_64.bundle";
      #sha256 = "2a967fe042c87b7a774ba1d5a7d63ee64f34b5220bf286370ca3439fed60487a";
      url = "http://127.0.0.1/public/VMware-Player-Full-16.2.3-19376536.x86_64.bundle";
      sha256 = "2c320084765b7a4cd79b6a0e834a6d315c4ecd61d0cc053aa7a445a7958738b0";
    };

    vmware-bundle = (import ./bundle (pkgs // {
      originalBundle = bundle;
      inherit version;
    }));
    vmware-vmx = import ./vmx { inherit pkgs; inherit vmware-bundle; inherit version; };
    vmware-kernel = (import ./kernel (pkgs // {
      inherit kernel;
      inherit vmware-bundle;
      inherit version;
    }));

    vmware-config = import ./vmware-config.nix {
      stdenv = pkgs.stdenv;
      inherit kernel;
      inherit vmware-vmx;
      inherit vmware-kernel;
      inherit version;
    };

    vmware-player-fhs = pkgs.buildFHSUserEnv {
      name = "vmware-player-fhs";

      targetPkgs = pkgs: with self.pkgs; [
        vmware-config
        vmware-vmx
        vmware-kernel
      ];

      profile = ''
        export VMWARE_VMX=${vmware-vmx}
        export VMWARE_CONFIG=${vmware-config}
        export VMWARE_KERNEL=${vmware-kernel}
        export VMWARE_BUNDLE=${vmware-bundle}
      '';

      extraBuildCommands = ''
      '';

      extraInstallCommands = ''
      '';

      runScript = "bash -l";
    };
  in
  {
    inherit vmware-bundle;
    inherit vmware-vmx;
    inherit vmware-kernel;
    inherit vmware-player-fhs;

    overlay = final: prev: {
      vmware-player = vmware-player-fhs;
      inherit vmware-bundle;
      inherit vmware-vmx;
      inherit vmware-kernel;
    };
    defaultPackage.x86_64-linux = vmware-player-fhs;
  };
}
