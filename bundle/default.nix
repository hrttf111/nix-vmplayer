{ lib
, stdenv
, bash
, file 
, patchelf
, python3
, python27
, glibc
, ncurses6
, ncurses5
, readline63
, xz
, bzip2
, sqlite
, zlib
}:
let
  my-python-packages = python-packages: with python-packages; [
    "binascii"
  ];
  python-with-my-packages = python3.withPackages my-python-packages;
  patchedBundle = "VMWare-patched.bundle";

  configurePhase12 = ''
    cat >> patches <<- EOM
    patchelf --replace-needed libpython2.7.so.1.0 ${python27}/lib/libpython2.7.so.1.0  \$so
    patchelf --replace-needed libncursesw.so.5 ${ncurses5}/lib/libncursesw.so.5  \$so
    patchelf --replace-needed libsqlite3.so.0 ${sqlite.out}/lib/libsqlite3.so.0  \$so
    patchelf --replace-needed libz.so.1 ${zlib}/lib/libz.so.1  \$so
    EOM
  '';

  configurePhase16 = ''
    cat >> patches <<- EOM
    patchelf --replace-needed libncursesw.so.6 ${ncurses6}/lib/libncursesw.so.6  \$so
    patchelf --replace-needed libreadline.so.6 ${readline63}/lib/libreadline.so.6  \$so
    patchelf --replace-needed libsqlite3.so.0 ${sqlite.out}/lib/libsqlite3.so.0  \$so
    patchelf --replace-needed libz.so.1 ${zlib}/lib/libz.so.1  \$so
    patchelf --replace-needed libbz2.so.1.0 ${bzip2.out}/lib/libbz2.so.1  \$so
    patchelf --replace-needed liblzma.so.5 ${xz.out}/lib/liblzma.so.5 \$so
    patchelf --replace-needed libpython3.9.so.1.0 \$VMIS_TEMP/install/vmware-installer/python/libpython3.9.so.1.0 \$so
    EOM
  '';

  mkBundle = configurePhase: version: originalBundle:
    stdenv.mkDerivation {
      pname = "vmware-bundle";
      inherit version;
      src = ./.;

      buildInputs = [
        bash
        file
        python3
        python27
        patchelf
        ncurses6
        ncurses5
        readline63
        xz
        bzip2
        sqlite
        zlib
        python-with-my-packages
      ];

      inherit configurePhase;

      buildPhase = ''
        python3 $src/bundle_tool.py --action=extract --bundle=${originalBundle} --launcher=launcher.sh
        $src/patch_launcher.sh ./launcher.sh "${glibc}" ./patches
        python3 $src/bundle_tool.py --action=replace --bundle=${originalBundle} --launcher=launcher.sh --new-bundle=${patchedBundle}

        chmod +x ./${patchedBundle}
        ./${patchedBundle} -x res
        rm ./${patchedBundle}
      '';

      installPhase = ''
        mkdir $out
        cp -r res/* $out/
      '';

      shellHook = ''
        export BUNDLE=${originalBundle}
      '';
    };
in
{
  mkBundle16 = mkBundle configurePhase16;
  mkBundle12 = mkBundle configurePhase12;
}
