{
  description = "vmware player try";

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
    nname = "VMware-Player-12.5.9-7535481.x86_64.bundle";
    #nname = "VMware-Player-14.1.7-12989993.x86_64.bundle";

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

    vmware-vmx = pkgs.stdenv.mkDerivation rec {
      name = "vmware-vmx";
      version = "0.1";
      src = ./.;
      buildInputs = with pkgs; [ ncurses5 python3 python27 sqlite patchelf zlib vmware-bundle ];

      configurePhase = ''
      '';

      installPhase = ''
        local vmware_installer_version=$(cat "vmware-installer/manifest.xml" | grep -oPm1 "(?<=<version>)[^<]+")
        set -x

        cp -r ${vmware-bundle} ./bundle
        bundleSource=./bundle

        mkdir $out
        pkgdir=$out
        vmware_installer_version=12.5.9
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
          ln -s /usr/lib/vmware/bin/appLoader "$pkgdir/usr/lib/vmware/bin/$link"
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
      '';

    };

    vmware-player = pkgs.stdenv.mkDerivation rec {
      name = "vmware-player";
      version = "0.1";
      src = ./.;
      buildInputs = with pkgs; [ ncurses5 python3 python27 sqlite patchelf zlib python-with-my-packages hexedit vmware-bundle vmware-vmx ];

      configurePhase = ''
      '';

      installPhase = ''
      '';

      shellHook = ''
        echo ${vmware-bundle}
        echo ${vmware-vmx}
        echo python=${pkgs.python27}
        echo ncurses5=${pkgs.ncurses5}
        echo sqlite=${pkgs.sqlite.out}
        echo zlib=${pkgs.zlib}
        echo glibc=${pkgs.glibc}
        export PYTHON_SO=${pkgs.python27}
        export NCURSES_SO=${pkgs.ncurses5}
        export SQLITE_SO=${pkgs.sqlite.out}
        export ZLIB_SO=${pkgs.zlib}
        export GLIBC_SO=${pkgs.glibc}
      '';
    };
  in
  {
    inherit vmware-player;
    overlay = final: prev: {
      vmware-player = vmware-player;
    };
    defaultPackage.x86_64-linux = vmware-player; 
  };
}
