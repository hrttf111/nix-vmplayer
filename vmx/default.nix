{ lib
, stdenv
, patchelf
, file
, rsync
, python3
, python27
, ncurses5
, sqlite
, zlib
, libxml2
, xorg
, libjpeg
, libpng12
, cups
, util-linux
, libuuid
, glibc

, debug ? true
}:
let

  configurePhase12 = ''
    cat >> patches <<- EOM
    patchelf --replace-needed libpython2.7.so.1.0 ${python27}/lib/libpython2.7.so.1.0 $elf
    patchelf --replace-needed libncursesw.so.5 ${ncurses5}/lib/libncursesw.so.5 $elf
    patchelf --replace-needed libsqlite3.so.0 ${sqlite.out}/lib/libsqlite3.so.0 $elf
    patchelf --replace-needed libz.so.1 ${zlib}/lib/libz.so.1 $elf
    patchelf --replace-needed libpng12.so.0 ${libpng12}/lib/libpng12.so.0 $elf
    patchelf --replace-needed libX11.so.6 ${xorg.libX11}/lib/libX11.so.6 $elf
    patchelf --replace-needed libXext.so.6 ${xorg.libXext}/lib/libXext.so.6 $elf
    patchelf --replace-needed libSM.so.6 ${xorg.libSM}/lib/libSM.so.6 $elf
    patchelf --replace-needed libICE.so.6 ${xorg.libSM}/lib/libSM.so.6 $elf
    patchelf --replace-needed libjpeg.so.62 ${libjpeg.out}/lib/libjpeg.so.62 $elf
    patchelf --replace-needed libcups.so.2 ${cups.out}/lib/libcups.so.2 $elf
    patchelf --replace-needed libXi.so.6 ${xorg.libXi}/lib/libXi.so.6 $elf
    patchelf --replace-needed libXtst.so.6 ${xorg.libXtst}/lib/libXtst.so.6 $elf
    EOM
  '';

  configurePhase14 = ''
    cat >> patches <<- EOM
    patchelf --replace-needed libpython2.7.so.1.0 ${python27}/lib/libpython2.7.so.1.0 $elf
    patchelf --replace-needed libcups.so.2 ${cups.out}/lib/libcups.so.2
    patchelf --replace-needed libuuid.so.1 ${libuuid.lib}/lib/libuuid.so.1
    EOM
  '';

  configurePhase16 = ''
    cat >> patches <<- EOM
    patchelf --replace-needed libcups.so.2 ${cups.out}/lib/libcups.so.2
    patchelf --replace-needed libuuid.so.1 ${libuuid.lib}/lib/libuuid.so.1
    EOM
  '';

  mkVmx = configurePhase: version: vmware-bundle:
    stdenv.mkDerivation {
      pname = "vmware-vmx";
      inherit version;
      src = ./.;

      buildInputs = [
        vmware-bundle

        patchelf
        file
        rsync
        python3
        python27
        ncurses5
        sqlite
        zlib
        libxml2
        xorg.libX11
        xorg.libXext
        xorg.libSM
        xorg.libICE
        xorg.libXi
        xorg.libXtst
        libjpeg
        libpng12
        cups
        util-linux
        libuuid
      ];

      inherit configurePhase;

      installPhase = ''
        mkdir $out

        ./install.sh "${vmware-bundle}" $out $src
        ./find_lib.sh "$out"

        echo "Start patching"
        ./bin_patches
        for filename in $(cat execs); do
          if [ -n "$(${file}/bin/file $filename | grep -i elf)" ]; then
            patchelf --set-interpreter ${glibc}/lib64/ld-linux-x86-64.so.2 $filename
          fi
        done
        echo "Finished patching"
      '' +
        (if debug then ''
          mkdir $out/usr/share/nix_debug
          cp patches $out/usr/share/nix_debug/patches
          cp bin_patches $out/usr/share/nix_debug/bin_patches
          cp not_found $out/usr/share/nix_debug/not_found
          cp execs $out/usr/share/nix_debug/execs
        '' else '''');
    };
in
{
  mkVmx12 = mkVmx configurePhase12;
  mkVmx14 = mkVmx configurePhase14;
  mkVmx16 = mkVmx configurePhase16;
}
