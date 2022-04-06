{ stdenv
, kernel
, patch
, fetchgit
, gcc
, gnumake
, ...
}:
let
  kversion = "${kernel.modDirVersion}";
  kinclude = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/";
  arch-patches-12 = fetchgit {
    url = "https://aur.archlinux.org/vmware-workstation12.git";
    rev  = "3bb2d09ad19572648938ea3c12bbe50d1b5051fd";
    hash = "sha256-hMY80rU8PZs3YPtGhTs0bmSq7u0oyzKkXP0X9eaAbMY";
  };
  arch-patches-16 = fetchgit {
    url  = "https://aur.archlinux.org/vmware-workstation.git";
    rev  = "1a9cfc692141619c665da33bcf9013d2c66e2c99";
    hash = "sha256-QgVHFwjrbpyHWBslhzY2Uwg4ts1cS2QRhrJUdF66B34";
  };
  mkKernel = patches: version: vmware-bundle:
    stdenv.mkDerivation {
      pname = "vmware-kernel";
      inherit version;
      src = ./.;

      hardeningDisable = [ "all" ];
      buildInputs = [
        gcc
        gnumake
        patch
        vmware-bundle
        patches
      ];
      nativeBuildInputs = kernel.moduleBuildDependencies;

      makeFlags = [
        "KVERSION=${kversion}"
        "LINUXINCLUDE=${kinclude}"
        "VM_KBUILD=yes"
      ];

      buildPhase = ''
        tar xf "${vmware-bundle}/vmware-vmx/lib/modules/source/vmmon.tar"
        cp -r ./vmmon-only ./vmmon
        tar xf "${vmware-bundle}/vmware-vmx/lib/modules/source/vmnet.tar"
        cp -r ./vmnet-only ./vmnet
        ${patch}/bin/patch -p1 < ${patches}/vmmon.patch
        ${patch}/bin/patch -p1 < ${patches}/vmnet.patch
        export KVERSION=${kversion}
        export LINUXINCLUDE=${kinclude}
        export VM_KBUILD=yes
        make -C ./vmmon
        make -C ./vmnet
      '';

      installPhase = ''
        binDir="$out/lib/modules/${kversion}/kernel/"
        mkdir -p $binDir
        cp ./vmmon/*.ko $binDir
        cp ./vmnet/*.ko $binDir
      '';

      shellHook = ''
        export KVERSION=${kversion}
        export LINUXINCLUDE=${kinclude}
        export VM_KBUILD=yes
      '';
    };
in
{
  mkKernel12 = mkKernel arch-patches-12;
  mkKernel16 = mkKernel arch-patches-16;
}
