{
  description = "vmware player try";

  outputs = { self, nixpkgs }:
  let
    #tar = builtins.fetchurl {
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
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
    my-python-packages = python-packages: with python-packages; [
      "binascii"
    ];
    python-with-my-packages = pkgs.python3.withPackages my-python-packages;
    vmware-player = pkgs.stdenv.mkDerivation rec {
      name = "vmware-player";
      version = "0.1";
      src = ./.;
      #tarfile = tar;
      #tarfile = vmp-source;
      buildInputs = with pkgs; [ ncurses5 python3 python27 sqlite patchelf zlib python-with-my-packages hexedit ];

      #builder = ./builder.sh;

      configurePhase = ''
      '';

      installPhase = ''
      '';

      shellHook = ''
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
