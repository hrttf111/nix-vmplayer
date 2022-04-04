{ stdenv, kernel, vmware-vmx, vmware-kernel, version }:

stdenv.mkDerivation {
  pname = "vmware-config";
  inherit version;
  buildInputs = [ vmware-vmx vmware-kernel ];

  src = ./.;

  installPhase = ''
    set -x
    mkdir -p $out/{etc,home,root,usr,bin}
    ln -s ${vmware-vmx}/usr/lib/vmware/bin/vmplayer $out/bin/vmplayer
    mkdir $out/etc/vmware
    cp -r ${vmware-vmx}/etc/vmware/* $out/etc/vmware
    VMWARE_DIR=${vmware-vmx}
    sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/vmware/bootstrap"
    sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/vmware/config"
    mkdir $out/etc/gtk-2.0
    cp $src/local_conf/etc/gtk-2.0/* $out/etc/gtk-2.0/
    sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/gtk-2.0/gdk-pixbuf.loaders"
    sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/gtk-2.0/gtk.immodules"
    mkdir $out/etc/pango
    cp $src/local_conf/home/pangox.aliases $out/etc/
    cp $src/local_conf/home/pango.modules $out/etc/
    cp $src/local_conf/home/pangorc $out/etc/pango/
    sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/pango.modules"
    cp $src/local_conf/home/vmware/preferences $out/etc/vmware/preferences
    echo 'mkdir ~/.vmware; cp /etc/vmware/preferences ~/.vmware/' > $out/bin/copy_pref
    chmod +x $out/bin/copy_pref
    echo "modprobe vmw_vmci; insmod ${vmware-kernel}/lib/modules/${kernel.modDirVersion}/kernel/vmmon.ko" > $out/bin/ins_mods
    chmod +x $out/bin/ins_mods
    rm $out/etc/vmware/icu
    ln -s ${vmware-vmx}/usr/lib/vmware/icu $out/etc/vmware/icu
  '';
}
