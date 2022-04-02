{
  description = "vmware player try";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
    kernel = nixpkgs.legacyPackages.x86_64-linux.pkgs.linux_5_15;
    nname = "VMware-Player-12.5.9-7535481.x86_64.bundle";

    my-python-packages = python-packages: with python-packages; [
      "binascii"
    ];
    python-with-my-packages = pkgs.python3.withPackages my-python-packages;
    vmware-bundle = pkgs.stdenv.mkDerivation rec {
      name = "vmware-player-bundle";
      version = "12.5.9";
      src = ./.;
      bundle = pkgs.fetchurl {
        #url = "https://download3.vmware.com/software/player/file/VMware-Player-14.1.7-12989993.x86_64.bundle";
        #url = "https://download3.vmware.com/software/player/file/VMware-Player-12.5.9-7535481.x86_64.bundle";
        url = "http://127.0.0.1/public/VMware-Player-12.5.9-7535481.x86_64.bundle";
        sha256 = "2a967fe042c87b7a774ba1d5a7d63ee64f34b5220bf286370ca3439fed60487a";
      };

      buildInputs = with pkgs; [ bash ncurses5 python3 python27 sqlite patchelf zlib python-with-my-packages hexedit ];
      patchedBundle = "${nname}.patched";

      configurePhase = ''
      '';

      buildPhase = ''
        export PYTHON_SO=${pkgs.python27}
        export NCURSES_SO=${pkgs.ncurses5}
        export SQLITE_SO=${pkgs.sqlite.out}
        export ZLIB_SO=${pkgs.zlib}
        export GLIBC_SO=${pkgs.glibc}
        export BASH_SH="${pkgs.bash}/bin/bash"

        ls -lah ${bundle}
        ls -lah ./
        
        python3 $src/bundle.py ${bundle} ./${patchedBundle} > result
        chmod +x ./${patchedBundle}
        echo "Patch done"
        ./${patchedBundle} -x res
        echo "Done"
      '';

      installPhase = ''
        mkdir $out
        echo Install
        ls -lah ./
        ls -lah ./${patchedBundle}
        #cp ./${patchedBundle} $out/
        cp ./launcher_patched.sh $out/
        cp ./result $out/
        cp -r res/* $out/
      '';
    };

    vmware-kernel = pkgs.stdenv.mkDerivation rec {
      name = "vmware-kernel";
      version = "0.3";
      src = ./.;

      hardeningDisable = [ "all" ];
      buildInputs = with pkgs; [ gcc gnumake vmware-bundle tree patch ];
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
        ${pkgs.patch}/bin/patch -p1 < $src/vmmon.patch
        export KVERSION=${kernel.modDirVersion}
        export LINUXINCLUDE=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/
        export VM_KBUILD=yes
        make -C ./vmmon
      '';

      installPhase = ''
        tree $src
        binDir="$out/lib/modules/${kernel.modDirVersion}/kernel/"
        mkdir -p $binDir
        cp ./vmmon/*.ko $binDir
      '';

      shellHook = ''
        export KVERSION=${kernel.modDirVersion}
        export LINUXINCLUDE=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/
        export VM_KBUILD=yes
      '';
    };

    vmware-vmx = pkgs.stdenv.mkDerivation rec {
      name = "vmware-vmx";
      version = "0.1";
      src = ./.;
      buildInputs = with pkgs; [
        vmware-bundle patchelf python3 file
        ncurses5 python27 sqlite zlib
        libxml2
        xorg.libX11 xorg.libXext xorg.libSM xorg.libICE xorg.libXi xorg.libXtst
        libjpeg libpng12
        cups
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
        #vmware_installer_version=12.5.9
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
          $bundleSource/vmware-vmx/lib/* \
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

        install -Dm 644 "$bundleSource/vmware-player-app/doc/LearnMore.txt" "$pkgdir/usr/share/licenses/$pkgname/Privacy.txt"
        install -Dm 644 "$pkgdir/usr/lib/vmware-ovftool/vmware.eula" "$pkgdir/usr/share/licenses/$pkgname/VMware OVF Tool - EULA.txt"
        rm "$pkgdir/usr/lib/vmware-ovftool"/{vmware.eula,vmware-eula.rtf,open_source_licenses.txt,manifest.xml}

        install -Dm 644 "$bundleSource/vmware-vmx/etc/modprobe.d/modprobe-vmware-fuse.conf" "$pkgdir/etc/modprobe.d/vmware-fuse.conf"

        install -Dm 644 $bundleSource/vmware-player-app/lib/isoimages/tools-key.pub "$pkgdir/usr/lib/vmware/isoimages/tools-key.pub"

        install -Dm 644 $bundleSource/vmware-vmx/extra/modules.xml "$pkgdir"/usr/lib/vmware/modules/modules.xml
        install -Dm 644 $bundleSource/vmware-installer/bootstrap "$pkgdir"/etc/vmware-installer/bootstrap

        rm -r "$pkgdir/usr/lib/vmware/xkeymap" # these files are provided by vmware-keymaps package

        chmod +x \
          "$pkgdir/usr/bin"/* \
          "$pkgdir/usr/lib/vmware/bin"/* \
          "$pkgdir/usr/lib/vmware/setup"/* \
          "$pkgdir/usr/lib/vmware/lib"/{wrapper-gtk24.sh,libgksu2.so.0/gksu-run-helper} \
          "$pkgdir/usr/lib/vmware-ovftool"/{ovftool,ovftool.bin} \
          "$pkgdir/usr/lib/vmware-installer/$vmware_installer_version"/{vmware-installer,vmis-launcher} \
          "$pkgdir/usr/lib/cups/filter"/*

        #chmod -R 600 "$pkgdir/etc/vmware/ssl"
        #chmod +s \
        #  "$pkgdir/usr/bin"/{vmware-authd,vmware-mount} \
        #  "$pkgdir/usr/lib/vmware/bin"/{vmware-vmx,vmware-vmx-debug,vmware-vmx-stats}

        for link in \
          licenseTool \
          thnuclnt \
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

        for file in \
          pango/pangorc \
          pango/pango.modules \
          pango/pangox.aliases \
          gtk-2.0/gdk-pixbuf.loaders \
          gtk-2.0/gtk.immodules
        do
          sed -i 's,@@LIBCONF_DIR@@,/usr/lib/vmware/libconf,g' "$pkgdir/usr/lib/vmware/libconf/etc/$file"
        done

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

        function patchElf() {
          elf=$1
          echo "Patch $elf"
          #patchelf --set-interpreter ${pkgs.glibc}/lib64/ld-linux-x86-64.so.2 $elf
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

          patchelf --replace-needed libatk-1.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libatk-1.0.so.0/libatk-1.0.so.0 $elf
          patchelf --replace-needed libatkmm-1.6.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libatkmm-1.6.so.1/libatkmm-1.6.so.1 $elf
          patchelf --replace-needed libatspi.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libatspi.so.0/libatspi.so.0 $elf
          patchelf --replace-needed libbasichttp.so ${placeholder "out"}/usr/lib/vmware/lib/libbasichttp.so/libbasichttp.so $elf
          patchelf --replace-needed libcairomm-1.0.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libcairomm-1.0.so.1/libcairomm-1.0.so.1 $elf
          patchelf --replace-needed libcairo.so.2 ${placeholder "out"}/usr/lib/vmware/lib/libcairo.so.2/libcairo.so.2 $elf
          patchelf --replace-needed libcds.so ${placeholder "out"}/usr/lib/vmware/lib/libcds.so/libcds.so $elf
          patchelf --replace-needed libcrypto.so.1.0.1 ${placeholder "out"}/usr/lib/vmware/lib/libcrypto.so.1.0.1/libcrypto.so.1.0.1 $elf
          patchelf --replace-needed libcurl.so.4 ${placeholder "out"}/usr/lib/vmware/lib/libcurl.so.4/libcurl.so.4 $elf
          patchelf --replace-needed libdbus-1.so.3 ${placeholder "out"}/usr/lib/vmware/lib/libdbus-1.so.3/libdbus-1.so.3 $elf
          patchelf --replace-needed libexpat.so.0 ${placeholder "out"}/usr/lib/vmware-ovftool/libexpat.so.0 $elf
          patchelf --replace-needed libfontconfig.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libfontconfig.so.1/libfontconfig.so.1 $elf
          patchelf --replace-needed libfreetype.so.6 ${placeholder "out"}/usr/lib/vmware/lib/libfreetype.so.6/libfreetype.so.6 $elf

          # for so in $(cat 5); do echo "patchelf --replace-needed $(basename $so) \${placeholder "out"}$so \$elf"; done
          patchelf --replace-needed libatk-1.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libatk-1.0.so.0/libatk-1.0.so.0 $elf
          patchelf --replace-needed libatkmm-1.6.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libatkmm-1.6.so.1/libatkmm-1.6.so.1 $elf
          patchelf --replace-needed libatspi.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libatspi.so.0/libatspi.so.0 $elf
          patchelf --replace-needed libbasichttp.so ${placeholder "out"}/usr/lib/vmware/lib/libbasichttp.so/libbasichttp.so $elf
          patchelf --replace-needed libcairomm-1.0.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libcairomm-1.0.so.1/libcairomm-1.0.so.1 $elf
          patchelf --replace-needed libcairo.so.2 ${placeholder "out"}/usr/lib/vmware/lib/libcairo.so.2/libcairo.so.2 $elf
          patchelf --replace-needed libcds.so ${placeholder "out"}/usr/lib/vmware/lib/libcds.so/libcds.so $elf
          patchelf --replace-needed libcrypto.so.1.0.1 ${placeholder "out"}/usr/lib/vmware/lib/libcrypto.so.1.0.1/libcrypto.so.1.0.1 $elf
          patchelf --replace-needed libcurl.so.4 ${placeholder "out"}/usr/lib/vmware/lib/libcurl.so.4/libcurl.so.4 $elf
          patchelf --replace-needed libdbus-1.so.3 ${placeholder "out"}/usr/lib/vmware/lib/libdbus-1.so.3/libdbus-1.so.3 $elf
          patchelf --replace-needed libexpat.so.0 ${placeholder "out"}/usr/lib/vmware-ovftool/libexpat.so.0 $elf
          patchelf --replace-needed libfontconfig.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libfontconfig.so.1/libfontconfig.so.1 $elf
          patchelf --replace-needed libfreetype.so.6 ${placeholder "out"}/usr/lib/vmware/lib/libfreetype.so.6/libfreetype.so.6 $elf
          patchelf --replace-needed libfuse.so.2 ${placeholder "out"}/usr/lib/vmware/lib/libfuse.so.2/libfuse.so.2 $elf
          patchelf --replace-needed libgailutil.so.18 ${placeholder "out"}/usr/lib/vmware/lib/libgailutil.so.18/libgailutil.so.18 $elf
          patchelf --replace-needed libgck.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgck.so.0/libgck.so.0 $elf
          patchelf --replace-needed libgcr.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgcr.so.0/libgcr.so.0 $elf
          patchelf --replace-needed libgcrypt.so.11 ${placeholder "out"}/usr/lib/vmware/lib/libgcrypt.so.11/libgcrypt.so.11 $elf
          patchelf --replace-needed libgdkmm-2.4.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libgdkmm-2.4.so.1/libgdkmm-2.4.so.1 $elf
          patchelf --replace-needed libgdk_pixbuf-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgdk_pixbuf-2.0.so.0/libgdk_pixbuf-2.0.so.0 $elf
          patchelf --replace-needed libgdk-x11-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgdk-x11-2.0.so.0/libgdk-x11-2.0.so.0 $elf
          patchelf --replace-needed libgio-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgio-2.0.so.0/libgio-2.0.so.0 $elf
          patchelf --replace-needed libgiomm-2.4.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libgiomm-2.4.so.1/libgiomm-2.4.so.1 $elf
          patchelf --replace-needed libgksu2.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgksu2.so.0/libgksu2.so.0 $elf
          patchelf --replace-needed libglib-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libglib-2.0.so.0/libglib-2.0.so.0 $elf
          patchelf --replace-needed libglibmm-2.4.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libglibmm-2.4.so.1/libglibmm-2.4.so.1 $elf
          patchelf --replace-needed libgmodule-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgmodule-2.0.so.0/libgmodule-2.0.so.0 $elf
          patchelf --replace-needed libgobject-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgobject-2.0.so.0/libgobject-2.0.so.0 $elf
          patchelf --replace-needed libgpg-error.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgpg-error.so.0/libgpg-error.so.0 $elf
          patchelf --replace-needed libgthread-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgthread-2.0.so.0/libgthread-2.0.so.0 $elf
          patchelf --replace-needed libgtkmm-2.4.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libgtkmm-2.4.so.1/libgtkmm-2.4.so.1 $elf
          patchelf --replace-needed libgtk-x11-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libgtk-x11-2.0.so.0/libgtk-x11-2.0.so.0 $elf
          patchelf --replace-needed libgtop-2.0.so.7 ${placeholder "out"}/usr/lib/vmware/lib/libgtop-2.0.so.7/libgtop-2.0.so.7 $elf
          patchelf --replace-needed libgvmomi.so ${placeholder "out"}/usr/lib/vmware/lib/libgvmomi.so/libgvmomi.so $elf
          patchelf --replace-needed libpango-1.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libpango-1.0.so.0/libpango-1.0.so.0 $elf
          patchelf --replace-needed libpangocairo-1.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libpangocairo-1.0.so.0/libpangocairo-1.0.so.0 $elf
          patchelf --replace-needed libpangoft2-1.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libpangoft2-1.0.so.0/libpangoft2-1.0.so.0 $elf
          patchelf --replace-needed libpangomm-1.4.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libpangomm-1.4.so.1/libpangomm-1.4.so.1 $elf
          patchelf --replace-needed libpangox-1.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libpangox-1.0.so.0/libpangox-1.0.so.0 $elf
          patchelf --replace-needed libpixman-1.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libpixman-1.so.0/libpixman-1.so.0 $elf
          patchelf --replace-needed librsvg-2.so.2 ${placeholder "out"}/usr/lib/vmware/lib/librsvg-2.so.2/librsvg-2.so.2 $elf
          patchelf --replace-needed libsigc-2.0.so.0 ${placeholder "out"}/usr/lib/vmware/lib/libsigc-2.0.so.0/libsigc-2.0.so.0 $elf
          patchelf --replace-needed libssl.so.1.0.1 ${placeholder "out"}/usr/lib/vmware/lib/libssl.so.1.0.1/libssl.so.1.0.1 $elf
          patchelf --replace-needed libssoclient.so ${placeholder "out"}/usr/lib/vmware-ovftool/libssoclient.so $elf
          patchelf --replace-needed libstdc++.so.6 ${placeholder "out"}/usr/lib/vmware/lib/libstdc++.so.6/libstdc++.so.6 $elf
          patchelf --replace-needed libview.so.3 ${placeholder "out"}/usr/lib/vmware/lib/libview.so.3/libview.so.3 $elf
          patchelf --replace-needed libvmacore.so ${placeholder "out"}/usr/lib/vmware-ovftool/libvmacore.so $elf
          patchelf --replace-needed libvmomi.so ${placeholder "out"}/usr/lib/vmware-ovftool/libvmomi.so $elf
          patchelf --replace-needed libvmwarebase.so ${placeholder "out"}/usr/lib/vmware/lib/libvmwarebase.so/libvmwarebase.so $elf
          patchelf --replace-needed libvmwareui.so ${placeholder "out"}/usr/lib/vmware/lib/libvmwareui.so/libvmwareui.so $elf
          patchelf --replace-needed libXau.so.6 ${placeholder "out"}/usr/lib/vmware/lib/libXau.so.6/libXau.so.6 $elf
          patchelf --replace-needed libXcomposite.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libXcomposite.so.1/libXcomposite.so.1 $elf
          patchelf --replace-needed libXcursor.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libXcursor.so.1/libXcursor.so.1 $elf
          patchelf --replace-needed libXdamage.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libXdamage.so.1/libXdamage.so.1 $elf
          patchelf --replace-needed libXfixes.so.3 ${placeholder "out"}/usr/lib/vmware/lib/libXfixes.so.3/libXfixes.so.3 $elf
          patchelf --replace-needed libXft.so.2 ${placeholder "out"}/usr/lib/vmware/lib/libXft.so.2/libXft.so.2 $elf
          patchelf --replace-needed libXinerama.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libXinerama.so.1/libXinerama.so.1 $elf
          patchelf --replace-needed libxml2.so.2 ${placeholder "out"}/usr/lib/vmware/lib/libxml2.so.2/libxml2.so.2 $elf
          patchelf --replace-needed libXrandr.so.2 ${placeholder "out"}/usr/lib/vmware/lib/libXrandr.so.2/libXrandr.so.2 $elf
          patchelf --replace-needed libXrender.so.1 ${placeholder "out"}/usr/lib/vmware/lib/libXrender.so.1/libXrender.so.1 $elf
        }

        for i in `seq 0 3`; do
          for lib in $(find $pkgdir -iname "*.so*"); do
            if [ -n "$(${pkgs.file}/bin/file $lib | grep -i elf)" ]; then
              patchElf $lib
            fi
          done
        done

        for lib in $(find $pkgdir -iname "*.so*"); do
          if [ -n "$(${pkgs.file}/bin/file $lib | grep -i elf)" ]; then
            echo "Show final LDD $elf"
            ldd $elf
          fi
        done

        patchelf --set-interpreter $GLIBC_SO/lib64/ld-linux-x86-64.so.2 $pkgdir/usr/lib/vmware-installer/$vmware_installer_version/vmis-launcher
        patchelf --set-interpreter $GLIBC_SO/lib64/ld-linux-x86-64.so.2 $pkgdir/usr/lib/vmware/setup/vmware-config

        for filename in $pkgdir/usr/bin/vmw*; do
          if [ -n "$(${pkgs.file}/bin/file $filename | grep -i elf)" ]; then
            patchelf --set-interpreter $GLIBC_SO/lib64/ld-linux-x86-64.so.2 $filename
            patchElf $filename
            ldd $filename
          fi
        done
        for filename in $pkgdir/usr/lib/vmware/bin/*; do
          if [ -n "$(${pkgs.file}/bin/file $filename | grep -i elf)" ]; then
            patchelf --set-interpreter $GLIBC_SO/lib64/ld-linux-x86-64.so.2 $filename
            patchElf $filename
            ldd $filename
          fi
        done
      '';

    };

    vmware-config = pkgs.stdenv.mkDerivation rec {
      name = "vmware-config";
      version = "0.1";
      buildInputs = with pkgs; [ vmware-vmx vmware-kernel ];

      src = ./.;

      installPhase = ''
        set -x
        mkdir -p $out/{etc,home,root,usr,bin}
        ln -s ${vmware-vmx}/usr/lib/vmware/bin/vmplayer $out/bin/vmplayer
        mkdir $out/etc/vmware
        cp $src/vmware-config $out/etc/vmware/config
        cp $src/vmware-config-bootstrap $out/etc/vmware/bootstrap
        #VMWARE_DIR=${placeholder "out"}
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
      '';
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
      '';

      extraBuildCommands = ''
      '';

      extraInstallCommands = ''
      '';

      runScript = "bash -l";
    };
  in
  {
    #inherit vmware-player;
    overlay = final: prev: {
      vmware-player = vmware-player-fhs;
    };
    defaultPackage.x86_64-linux = vmware-player-fhs;
  };
}
