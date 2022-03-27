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
    vmware-player = pkgs.stdenv.mkDerivation rec {
      name = "vmware-player";
      version = "0.1";
      src = ./.;
      #tarfile = tar;
      #tarfile = vmp-source;
      buildInputs = with pkgs; [ ncurses5 python27 sqlite patchelf zlib ];

      builder = ./builder.sh;

      configurePhase = ''
      '';

      installPhase = ''
      '';

      shellHook = ''
        echo python=${pkgs.python27}
        echo ncurses5=${pkgs.ncurses5}
        echo sqlite=${pkgs.sqlite}
        echo zlib=${pkgs.zlib}
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
