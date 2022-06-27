{ stdenv
, kernel
, vmware-vmx
, vmware-kernel
, version
}:
stdenv.mkDerivation {
  pname = "vmware-config";
  inherit version;
  buildInputs = [ vmware-vmx vmware-kernel ];

  dontUnpack = true;

  installPhase = ''
    set -x
    mkdir -p $out/{etc,home,root,usr,bin}
    ln -s ${vmware-vmx}/usr/lib/vmware/bin/vmplayer $out/bin/vmplayer

    mkdir $out/etc/vmware
    echo 'mkdir ~/.vmware; cp /etc/vmware/preferences ~/.vmware/' > $out/bin/copy_pref
    chmod +x $out/bin/copy_pref
    echo "modprobe vmw_vmci; insmod ${vmware-kernel}/lib/modules/${kernel.modDirVersion}/kernel/vmmon.ko" > $out/bin/ins_mods
    chmod +x $out/bin/ins_mods
    ln -s ${vmware-vmx}/usr/lib/vmware/icu $out/etc/vmware/icu
  '';
}
