{ stdenv
, kernel
, patch
, gcc
, gnumake

, vmware-bundle
, version
, ...
}:

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
  ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = [
    "KVERSION=${kernel.modDirVersion}"
    "LINUXINCLUDE=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/"
    "VM_KBUILD=yes"
  ];
  #patches = [ ./vmmon.patch ];

  unpackPhase = ''
  '';

  buildPhase = ''
    tar xf "${vmware-bundle}/vmware-vmx/lib/modules/source/vmmon.tar"
    cp -r ./vmmon-only ./vmmon
    ${patch}/bin/patch -p1 < $src/vmmon.patch
    export KVERSION=${kernel.modDirVersion}
    export LINUXINCLUDE=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/
    export VM_KBUILD=yes
    make -C ./vmmon
  '';

  installPhase = ''
    binDir="$out/lib/modules/${kernel.modDirVersion}/kernel/"
    mkdir -p $binDir
    cp ./vmmon/*.ko $binDir
  '';

  shellHook = ''
    export KVERSION=${kernel.modDirVersion}
    export LINUXINCLUDE=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/
    export VM_KBUILD=yes
  '';
}
