{ stdenv
, kernel
, patch
, gcc
, gnumake
, ...
}:
let
  kversion = "${kernel.modDirVersion}";
  kinclude = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/";
in
version: patches: vmware-bundle:
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
  }
