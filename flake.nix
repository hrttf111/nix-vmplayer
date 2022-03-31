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

    vmware-player = pkgs.stdenv.mkDerivation rec {
      name = "vmware-player";
      version = "0.1";
      src = ./.;
      buildInputs = with pkgs; [ ncurses5 python3 python27 sqlite patchelf zlib python-with-my-packages hexedit vmware-bundle ];

      configurePhase = ''
      '';

      installPhase = ''
      '';

      shellHook = ''
        echo ${vmware-bundle}
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
