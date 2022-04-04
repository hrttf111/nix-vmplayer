{ pkgs, version, vmware-bundle }:
let
in

pkgs.stdenv.mkDerivation {
  pname = "vmware-vmx";
  inherit version;
  src = ./.;

  buildInputs = with pkgs; [
    vmware-bundle patchelf python3 file
    ncurses5 python27 sqlite zlib
    libxml2
    xorg.libX11 xorg.libXext xorg.libSM xorg.libICE xorg.libXi xorg.libXtst
    libjpeg libpng12
    cups
    util-linux
    libuuid
  ];

  configurePhase = ''
  '';

  installPhase = ''
    PYTHON_SO=${pkgs.python27}
    NCURSES_SO=${pkgs.ncurses5}
    SQLITE_SO=${pkgs.sqlite.out}
    ZLIB_SO=${pkgs.zlib}
    GLIBC_SO=${pkgs.glibc}

    local vmware_installer_version=$(cat "${vmware-bundle}/vmware-installer/manifest.xml" | grep -oPm1 "(?<=<version>)[^<]+")
    set -x

    cp -r ${vmware-bundle} ./bundle
    bundleSource=./bundle

    mkdir $out
    pkgdir=$out
    #vmware_installer_version=16.2.3
    mkdir -p \
      "$pkgdir/etc"/{cups,pam.d,modprobe.d,thnuclnt,vmware} \
      "$pkgdir/usr"/{share,bin} \
      "$pkgdir/usr/include/vmware-vix" \
      "$pkgdir/usr/lib"/{vmware/setup,vmware-vix,vmware-ovftool,vmware-installer/"$vmware_installer_version",cups/filter,modules-load.d} \
      "$pkgdir/usr/share"/{doc/vmware-vix,licenses/"$pkgname"} \
      "$pkgdir/var/lib/vmware/Shared VMs"

    #install -Dm 644 vmware-installer/bootstrap "$out"/etc/vmware-installer/bootstrap

    chmod +w -R $pkgdir/*
    chmod +w -R $bundleSource

    cp -r \
      $bundleSource/vmware-player/share/* \
      $bundleSource/vmware-player-app/share/* \
      "$pkgdir/usr/share"

    cp -r \
      $bundleSource/vmware-vmx/{,s}bin/* \
      $bundleSource/vmware-player-app/bin/* \
      "$pkgdir/usr/bin"

    cp -r \
      $bundleSource/vmware-player/lib/* \
      $bundleSource/vmware-player-app/lib/* \
      $bundleSource/vmware-vmx/{lib/*,roms} \
      $bundleSource/vmware-usbarbitrator/bin \
      $bundleSource/vmware-network-editor/lib \
      "$pkgdir/usr/lib/vmware"

    cp -r \
      $bundleSource/vmware-player-setup/vmware-config \
      "$pkgdir/usr/lib/vmware/setup"

    cp -r \
      $bundleSource/vmware-ovftool/* \
      "$pkgdir/usr/lib/vmware-ovftool"

    cp -r \
      $bundleSource/vmware-installer/{python,sopython,vmis,vmis-launcher,vmware-installer,vmware-installer.py} \
      "$pkgdir/usr/lib/vmware-installer/$vmware_installer_version"

    cp -r \
      $bundleSource/vmware-player-app/etc/cups/* \
      "$pkgdir/etc/cups"

    cp -r \
      $bundleSource/vmware-player-app/extras/thnucups \
      "$pkgdir/usr/lib/cups/filter"

    #install -Dm 644 "$bundleSource/vmware-player-app/doc/LearnMore.txt" "$pkgdir/usr/share/licenses/$pkgname/Privacy.txt"
    install -Dm 644 "$pkgdir/usr/lib/vmware-ovftool/vmware.eula" "$pkgdir/usr/share/licenses/$pkgname/VMware OVF Tool - EULA.txt"
    rm "$pkgdir/usr/lib/vmware-ovftool"/{vmware.eula,vmware-eula.rtf,open_source_licenses.txt,manifest.xml}

    install -Dm 644 "$bundleSource/vmware-vmx/etc/modprobe.d/modprobe-vmware-fuse.conf" "$pkgdir/etc/modprobe.d/vmware-fuse.conf"

    #install -Dm 644 $bundleSource/vmware-player-app/lib/isoimages/tools-key.pub "$pkgdir/usr/lib/vmware/isoimages/tools-key.pub"

    install -Dm 644 $bundleSource/vmware-vmx/extra/modules.xml "$pkgdir"/usr/lib/vmware/modules/modules.xml
    install -Dm 644 $bundleSource/vmware-installer/bootstrap "$pkgdir"/etc/vmware-installer/bootstrap

    rm -r "$pkgdir/usr/lib/vmware/xkeymap" # these files are provided by vmware-keymaps package

    chmod +x \
      "$pkgdir/usr/bin"/* \
      "$pkgdir/usr/lib/vmware/bin"/* \
      "$pkgdir/usr/lib/vmware/setup"/* \
      "$pkgdir/usr/lib/vmware-ovftool"/{ovftool,ovftool.bin} \
      "$pkgdir/usr/lib/vmware-installer/$vmware_installer_version"/{vmware-installer,vmis-launcher} \
      "$pkgdir/usr/lib/cups/filter"/*

    #chmod -R 600 "$pkgdir/etc/vmware/ssl"
    #chmod +s \
    #  "$pkgdir/usr/bin"/{vmware-authd,vmware-mount} \
    #  "$pkgdir/usr/lib/vmware/bin"/{vmware-vmx,vmware-vmx-debug,vmware-vmx-stats}

    for link in \
      licenseTool \
      vmplayer \
      vmware \
      vmware-app-control \
      vmware-enter-serial \
      vmware-fuseUI \
      vmware-gksu \
      vmware-modconfig \
      vmware-modconfig-console \
      vmware-netcfg \
      vmware-tray \
      vmware-unity-helper \
      vmware-vmblock-fuse \
      vmware-zenity
    do
      ln -s $pkgdir/usr/lib/vmware/bin/appLoader "$pkgdir/usr/lib/vmware/bin/$link"
    done

#        for file in \
#          pango/pangorc \
#          pango/pango.modules \
#          pango/pangox.aliases \
#          gtk-2.0/gdk-pixbuf.loaders \
#          gtk-2.0/gtk.immodules
#        do
#          sed -i 's,@@LIBCONF_DIR@@,/usr/lib/vmware/libconf,g' "$pkgdir/usr/lib/vmware/libconf/etc/$file"
#        done

    # create symlinks (replicate installer) - misc
    ln -s $out/lib/vmware/icu $out/etc/vmware/icu
    #ln -s $out/lib/vmware/lib/diskLibWrapper.so/diskLibWrapper.so $out/lib/diskLibWrapper.so
    #ln -s $out/lib/vmware/lib/libvmware-hostd.so/libvmware-hostd.so $out/lib/vmware/lib/libvmware-vim-cmd.so/libvmware-vim-cmd.so
    #ln -s $out/lib/vmware-ovftool/ovftool $out/bin/ovftool

    # create database of vmware guest tools (avoids vmware fetching them later)
    local database_filename=$out/etc/vmware-installer/database
    echo -n "" > $database_filename
    sqlite3 "$database_filename" "CREATE TABLE settings(key VARCHAR PRIMARY KEY, value VARCHAR NOT NULL, component_name VARCHAR NOT NULL);"
    sqlite3 "$database_filename" "INSERT INTO settings(key,value,component_name) VALUES('db.schemaVersion','2','vmware-installer');"
    sqlite3 "$database_filename" "CREATE TABLE components(id INTEGER PRIMARY KEY, name VARCHAR NOT NULL, version VARCHAR NOT NULL, buildNumber INTEGER NOT NULL, component_core_id INTEGER NOT NULL, longName VARCHAR NOT NULL, description VARCHAR, type INTEGER NOT NULL);"
    for isoimage in linux linuxPreGlibc25 netware solaris windows winPre2k winPreVista; do
#        local iso_version=$(cat vmware-tools-$isoimage/manifest.xml | grep -oPm1 "(?<=<version>)[^<]+")
      sqlite3 "$database_filename" "INSERT INTO components(name,version,buildNumber,component_core_id,longName,description,type) VALUES(\"vmware-tools-$isoimage\",\"$iso_version\",\"${version}\",1,\"$isoimage\",\"$isoimage\",1);"
    done

    install -m644 $src/vmware-config-bootstrap "$out"/etc/vmware/bootstrap
    install -Dm 644 $src/vmware-config "$out"/etc/vmware/config

    echo "patchelf --replace-needed libcups.so.2 ${pkgs.cups.out}/lib/libcups.so.2" > patches
    #echo "patchelf --replace-needed libuuid.so.1 ${pkgs.util-linux.out}/lib/libuuid.so.1" >> patches
    echo "patchelf --replace-needed libuuid.so.1 ${pkgs.libuuid.lib}/lib/libuuid.so.1" >> patches
    ./find_lib.sh "$pkgdir"
    echo "Start patching"
    ./bin_patches

    function patchElf() {
      elf=$1
      patchelf --replace-needed libpython2.7.so.1.0 ${pkgs.python27}/lib/libpython2.7.so.1.0 $elf
      patchelf --replace-needed libncursesw.so.5 ${pkgs.ncurses5}/lib/libncursesw.so.5 $elf
      patchelf --replace-needed libsqlite3.so.0 ${pkgs.sqlite.out}/lib/libsqlite3.so.0 $elf
      patchelf --replace-needed libz.so.1 ${pkgs.zlib}/lib/libz.so.1 $elf
      patchelf --replace-needed libpng12.so.0 ${pkgs.libpng12}/lib/libpng12.so.0 $elf
      patchelf --replace-needed libX11.so.6 ${pkgs.xorg.libX11}/lib/libX11.so.6 $elf
      patchelf --replace-needed libXext.so.6 ${pkgs.xorg.libXext}/lib/libXext.so.6 $elf
      patchelf --replace-needed libSM.so.6 ${pkgs.xorg.libSM}/lib/libSM.so.6 $elf
      patchelf --replace-needed libICE.so.6 ${pkgs.xorg.libSM}/lib/libSM.so.6 $elf
      patchelf --replace-needed libjpeg.so.62 ${pkgs.libjpeg.out}/lib/libjpeg.so.62 $elf
      patchelf --replace-needed libcups.so.2 ${pkgs.cups.out}/lib/libcups.so.2 $elf
      patchelf --replace-needed libXi.so.6 ${pkgs.xorg.libXi}/lib/libXi.so.6 $elf
      patchelf --replace-needed libXtst.so.6 ${pkgs.xorg.libXtst}/lib/libXtst.so.6 $elf
    }

    for filename in $(cat execs); do
      if [ -n "$(${pkgs.file}/bin/file $filename | grep -i elf)" ]; then
        patchelf --set-interpreter $GLIBC_SO/lib64/ld-linux-x86-64.so.2 $filename
      fi
    done
    echo "Stop patching"

    mkdir $pkgdir/usr/share/nix_debug
    cp patches $pkgdir/usr/share/nix_debug/patches
    cp bin_patches $pkgdir/usr/share/nix_debug/bin_patches
    cp not_found $pkgdir/usr/share/nix_debug/not_found
    cp execs $pkgdir/usr/share/nix_debug/execs
  '';
}
