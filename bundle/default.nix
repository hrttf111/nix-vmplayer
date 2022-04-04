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
    export PYTHON_SO=${python3}
    export NCURSES_SO=${ncurses6}
    export READLINE_SO=${readline63}
    export SQLITE_SO=${sqlite.out}
    export BZIP_SO=${bzip2.out}
    export LZMA_SO=${xz.out}
    export ZLIB_SO=${zlib}
    export GLIBC_SO=${glibc}
    export BASH_SH="${bash}/bin/bash"

    python3 $src/bundle.py ${originalBundle} ./${patchedBundle} > result
    chmod +x ./${patchedBundle}
    ./${patchedBundle} -x res
  '';

  installPhase = ''
    mkdir $out
    cp -r res/* $out/
  '';

  shellHook = ''
    export PYTHON_SO=${python3}
    export NCURSES_SO=${ncurses6}
    export READLINE_SO=${readline63}
    export SQLITE_SO=${sqlite.out}
    export BZIP_SO=${bzip2.out}
    export LZMA_SO=${xz.out}
    export ZLIB_SO=${zlib}
    export GLIBC_SO=${glibc}
    export BASH_SH="${bash}/bin/bash"
    export BUNDLE=${originalBundle}
    echo ${python-with-my-packages}
  '';
}
