{
  description = "vmware player try";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
    kernel = nixpkgs.legacyPackages.x86_64-linux.pkgs.linux_5_15;
    #nname = "VMware-Player-12.5.9-7535481.x86_64.bundle";
    nname = "VMware-Player-Full-16.2.3-19376536.x86_64.bundle";

    my-python-packages = python-packages: with python-packages; [
      "binascii" "zlib"
    ];
    python-with-my-packages = pkgs.python3.withPackages my-python-packages;
    vmware-bundle = pkgs.stdenv.mkDerivation rec {
      name = "vmware-player-bundle";
      version = "16.2.3";
      src = ./.;
      bundle = pkgs.fetchurl {
        #url = "https://download3.vmware.com/software/player/file/VMware-Player-14.1.7-12989993.x86_64.bundle";
        #url = "https://download3.vmware.com/software/player/file/VMware-Player-12.5.9-7535481.x86_64.bundle";
        #url = "http://127.0.0.1/public/VMware-Player-12.5.9-7535481.x86_64.bundle";
        url = "http://127.0.0.1/public/VMware-Player-Full-16.2.3-19376536.x86_64.bundle";
        #sha256 = "2a967fe042c87b7a774ba1d5a7d63ee64f34b5220bf286370ca3439fed60487a";
        sha256 = "2c320084765b7a4cd79b6a0e834a6d315c4ecd61d0cc053aa7a445a7958738b0";
      };

      buildInputs = with pkgs; [ bash ncurses6 readline63 python39 xz bzip2 sqlite patchelf zlib python-with-my-packages hexedit file ];
      patchedBundle = "${nname}.patched";

      configurePhase = ''
      '';

      buildPhase = ''
        set -x
        export PYTHON_SO=${pkgs.python39}
        export NCURSES_SO=${pkgs.ncurses6}
        export READLINE_SO=${pkgs.readline63}
        export SQLITE_SO=${pkgs.sqlite.out}
        export BZIP_SO=${pkgs.bzip2.out}
        export LZMA_SO=${pkgs.xz.out}
        export ZLIB_SO=${pkgs.zlib}
        export GLIBC_SO=${pkgs.glibc}
        export BASH_SH="${pkgs.bash}/bin/bash"

        ls -lah ${bundle}
        ls -lah ./

        python3 $src/bundle.py ${bundle} ./${patchedBundle} > result
        chmod +x ./${patchedBundle}
        echo "Patch done"
        VMIS_KEEP_TEMP=1 ./${patchedBundle} -x res
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

      shellHook = ''
        export PYTHON_SO=${pkgs.python39}
        export NCURSES_SO=${pkgs.ncurses6}
        export READLINE_SO=${pkgs.readline63}
        export SQLITE_SO=${pkgs.sqlite.out}
        export BZIP_SO=${pkgs.bzip2.out}
        export LZMA_SO=${pkgs.xz.out}
        export ZLIB_SO=${pkgs.zlib}
        export GLIBC_SO=${pkgs.glibc}
        export BASH_SH="${pkgs.bash}/bin/bash"
        export BUNDLE=${bundle}
        echo ${python-with-my-packages}
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

#        for elf in $(find $pkgdir -iname "*.so*"); do
#          if [ -n "$(${pkgs.file}/bin/file $lib | grep -i elf)" ]; then
#            echo "Show final LDD $elf"
#            ldd $elf
#          fi
#        done
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
      #vmware-player = vmware-bundle;
      #vmware-player = vmware-vmx;
    };
    defaultPackage.x86_64-linux = vmware-player-fhs;
    #defaultPackage.x86_64-linux = vmware-bundle;
    #defaultPackage.x86_64-linux = vmware-vmx;
  };
}
