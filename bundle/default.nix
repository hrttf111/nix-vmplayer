{ pkgs, version, originalBundle }:
let
  my-python-packages = python-packages: with python-packages; [
    "binascii" "zlib"
  ];
  python-with-my-packages = pkgs.python3.withPackages my-python-packages;
  patchedBundle = "VMWare-patched.bundle";
in

pkgs.stdenv.mkDerivation {
  pname = "vmware-bundle";
  inherit version;
  src = ./.;

  buildInputs = with pkgs; [ bash ncurses6 readline63 python39 xz bzip2 sqlite patchelf zlib python-with-my-packages hexedit file ];

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

    python3 $src/bundle.py ${originalBundle} ./${patchedBundle} > result
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
    export BUNDLE=${originalBundle}
    echo ${python-with-my-packages}
  '';
}
