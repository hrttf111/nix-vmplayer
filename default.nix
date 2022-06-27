{ callPackage
, fetchurl
, fetchgit
, buildFHSUserEnv
, kernel
}:
let
  mkBundles = callPackage ./bundle {};
  mkVmxs = callPackage ./vmx {};
  mkKernel = callPackage ./vmware-kernel.nix { inherit kernel; };

  mkVmwarePlayer = {version, bundle, kernelPatches, mkBundle, mkVmx}: rec {
    vmware-bundle = mkBundle version bundle;
    vmware-vmx = mkVmx version vmware-bundle;
    vmware-kernel = mkKernel version kernelPatches vmware-bundle;
    vmware-config = callPackage ./vmware-config.nix {
      inherit kernel;
      inherit vmware-vmx;
      inherit vmware-kernel;
      inherit version;
    };
    fhs = buildFHSUserEnv {
      name = "vmware-player-fhs-${version}";
      targetPkgs = pkgs: [
        vmware-config
        vmware-vmx
        vmware-kernel
      ];
      profile = ''
        export VMWARE_VMX=${vmware-vmx}
        export VMWARE_CONFIG=${vmware-config}
        export VMWARE_KERNEL=${vmware-kernel}
      '';
      runScript = "bash -l";
    };
  };
in
{
  vmware-player-12 = mkVmwarePlayer {
    version = "12.5.9";
    bundle = fetchurl {
      url = "http://127.0.0.1:8000/VMware-Player-12.5.9-7535481.x86_64.bundle";
      sha256 = "2a967fe042c87b7a774ba1d5a7d63ee64f34b5220bf286370ca3439fed60487a";
    };
    kernelPatches = fetchgit {
      url = "https://aur.archlinux.org/vmware-workstation12.git";
      rev  = "3bb2d09ad19572648938ea3c12bbe50d1b5051fd";
      hash = "sha256-hMY80rU8PZs3YPtGhTs0bmSq7u0oyzKkXP0X9eaAbMY";
    };
    mkBundle = mkBundles.mkBundle12;
    mkVmx = mkVmxs.mkVmx12;
  };

  vmware-player-14 = mkVmwarePlayer {
    version = "14.1.7";
    bundle = fetchurl {
      url = "http://127.0.0.1:8000/VMware-Player-14.1.7-12989993.x86_64.bundle";
      sha256 = "f595e14af39848936cfc4105140c488bce1e47ec950b3f61ea888b3fdca24b71";
    };
    kernelPatches = fetchgit {
      url  = "https://aur.archlinux.org/vmware-workstation14.git";
      #rev  = "70e5ad79c923c691cb607c575f9d1cc6681b2466";
      #hash = "sha256-mqo4YvF91um/1i34aejBvBOTUioSiMUfycmydyFedRs";
      rev  = "6d8e05cfd19e1149176c802671e9cfc9be853d2a";
      hash = "sha256-UBbcEyyQcbOet2GxOnofedpcFT1LeiCY8FEhsPdtOqQ=";
    };
    mkBundle = mkBundles.mkBundle12;
    mkVmx = mkVmxs.mkVmx14;
  };

  vmware-player-15 = mkVmwarePlayer {
    version = "15.5.7";
    bundle = fetchurl {
      url = "http://127.0.0.1:8000/VMware-Player-15.5.7-17171714.x86_64.bundle";
      sha256 = "782d5fd5faf9e775c0d5fe56a829a8fb811c6717b8a924a1eda7f57c43c88370";
    };
    kernelPatches = fetchgit {
      url = "https://aur.archlinux.org/vmware-workstation15.git";
      #rev  = "58259609c60ecd1dd070b4b8a1fe266c99519e88";
      #hash = "sha256-9ChvVyuubES7t2I0oQI8kicyKAQ54K7q2BthHqr04/g=";
      rev = "aa31c43e6c3f0722bc7bfa8ecc33c3727a604769";
      hash = "sha256-ZIhxg7Ji8DZL3X2NLxvlzzC1apkM5btWhHezah87Kz8=";
    };
    mkBundle = mkBundles.mkBundle16;
    mkVmx = mkVmxs.mkVmx16;
  };

  vmware-player-16 = mkVmwarePlayer {
    version = "16.2.3";
    bundle = fetchurl {
      url = "http://127.0.0.1:8000/VMware-Player-Full-16.2.3-19376536.x86_64.bundle";
      sha256 = "2c320084765b7a4cd79b6a0e834a6d315c4ecd61d0cc053aa7a445a7958738b0";
    };
    kernelPatches = fetchgit {
      url  = "https://aur.archlinux.org/vmware-workstation.git";
      rev  = "1a9cfc692141619c665da33bcf9013d2c66e2c99";
      hash = "sha256-QgVHFwjrbpyHWBslhzY2Uwg4ts1cS2QRhrJUdF66B34";
    };
    mkBundle = mkBundles.mkBundle16;
    mkVmx = mkVmxs.mkVmx16;
  };
}
