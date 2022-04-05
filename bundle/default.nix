{ lib
, stdenv
, bash
, file 
, patchelf
, python3
, glibc
, ncurses6
, readline63
, xz
, bzip2
, sqlite
, zlib

, version
, originalBundle
, ...
}:
let
  my-python-packages = python-packages: with python-packages; [
    "binascii" "zlib"
  ];
  python-with-my-packages = python3.withPackages my-python-packages;
  patchedBundle = "VMWare-patched.bundle";
in

stdenv.mkDerivation {
  pname = "vmware-bundle";
  inherit version;
  src = ./.;

  buildInputs = [
    bash
    file
    python3
    patchelf
    ncurses6
    readline63
    xz
    bzip2
    sqlite
    zlib
    python-with-my-packages
  ];

  buildPhase = ''
    set -x
    export BASH_SH="${bash}/bin/bash"

    cat >> patches <<- EOM
    patchelf --replace-needed libncursesw.so.6 ${ncurses6}/lib/libncursesw.so.6  \$so
    patchelf --replace-needed libreadline.so.6 ${readline63}/lib/libreadline.so.6  \$so
    patchelf --replace-needed libsqlite3.so.0 ${sqlite.out}/lib/libsqlite3.so.0  \$so
    patchelf --replace-needed libz.so.1 ${zlib}/lib/libz.so.1  \$so
    patchelf --replace-needed libbz2.so.1.0 ${bzip2.out}/lib/libbz2.so.1  \$so
    patchelf --replace-needed liblzma.so.5 ${xz.out}/lib/liblzma.so.5 \$so
    EOM

    python3 $src/bundle_tool.py --action=extract --bundle=${originalBundle} --launcher=launcher.sh
    $src/patch_launcher.sh ./launcher.sh "${glibc}" ./patches
    python3 $src/bundle_tool.py --action=replace --bundle=${originalBundle} --launcher=launcher.sh --new-bundle=${patchedBundle}

    chmod +x ./${patchedBundle}
    ./${patchedBundle} -x res
  '';

  installPhase = ''
    mkdir $out
    cp -r res/* $out/
  '';

  shellHook = ''
    export BUNDLE=${originalBundle}
    echo ${python-with-my-packages}
  '';
}
