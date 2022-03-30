{
  description = "vmware player try";

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
    #bundlePath = "file:///opt/projects/temp/1/VMware-Player-12.5.9-7535481.x86_64.bundle";
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
        #sha256 = "1ac8xhvw5gv95mql7684iimqrbvxwblpiwis21v3lw3l34pyrf1n";
        sha256 = "2a967fe042c87b7a774ba1d5a7d63ee64f34b5220bf286370ca3439fed60487a";
      };
#      bundle = pkgs.stdenv.mkDerivation {
#        name = "vmware-player-bundle";
#        src = bundlePath;
#        configurePhase = ''
#        '';
#        installPhase = ''
#          mkdir $out
#          cp $src $out/
#        '';
#      };

      buildInputs = with pkgs; [ bash ncurses5 python3 python27 sqlite patchelf zlib python-with-my-packages hexedit ];

      configurePhase = ''
      '';

      buildPhase = ''
        export PYTHON_SO=${pkgs.python27}
        export NCURSES_SO=${pkgs.ncurses5}
        export SQLITE_SO=${pkgs.sqlite.out}
        export ZLIB_SO=${pkgs.zlib}
        export GLIBC_SO=${pkgs.glibc}

        ls -lah ${bundle}
        ls -lah ./

        patchedBundle=./"${nname}"
        python3 $src/bundle.py ${bundle} "$patchedBundle.patched"
        mkdir res
        chmod +x $patchedBundle.patched
        patchShebangs $patchedBundle.patched
        echo "Patch done"
        $patchedBundle.patched -x res
        echo "Done"
      '';

      installPhase = ''
        mkdir out
        cp -r res/* out/
      '';
    };
    #bundle = pkgs.stdenv.mkDerivation {
    #  name = "vmware-player-bundle";
    #  src = "/opt/projects/temp/1/VMware-Player-12.5.9-7535481.x86_64.bundle";
    #};
    #tar = pkgs.fetchzip {
    #  url = "/home/ddd/vmplayer.tar.gz";
    #  sha256 = "1111111111111111111111111111111111111111111111111111";
    #};
    #vmp-source = pkgs.stdenv.mkDerivation {
    #  name = "vmware-player-src";
    #  src = "/opt/projects/temp/vmplayer.tar";
    #  #src = ./vmplayer.tar;
    #  installPhase = ''
    #    mkdir $out
    #    cp -r ./* $out/
    #  '';
    #};
    vmware-player = pkgs.stdenv.mkDerivation rec {
      name = "vmware-player";
      version = "0.1";
      src = ./.;
      #tarfile = tar;
      #tarfile = vmp-source;
      buildInputs = with pkgs; [ ncurses5 python3 python27 sqlite patchelf zlib python-with-my-packages hexedit vmware-bundle ];

      #builder = ./builder.sh;

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
