{
  description = "VMWare Player";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.05";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ self.overlay ];
    };
    run-nginx = pkgs.callPackage ./local-images.nix { mkDerivation = pkgs.stdenv.mkDerivation; };
  in
  {
    vmware-player-12 = pkgs.allVmware.vmware-player-12;
    vmware-player-14 = pkgs.allVmware.vmware-player-14;
    vmware-player-15 = pkgs.allVmware.vmware-player-15;
    vmware-player-16 = pkgs.allVmware.vmware-player-16;
    inherit run-nginx;

    overlay = final: prev: let
      allVmware = final.callPackage ./default.nix { kernel = final.linux_5_15; };
    in {
      inherit allVmware;
      vmware-player-12 = allVmware.vmware-player-12.fhs;
      vmware-player-14 = allVmware.vmware-player-14.fhs;
      vmware-player-15 = allVmware.vmware-player-15.fhs;
      vmware-player-16 = allVmware.vmware-player-16.fhs;
    };
    defaultPackage.x86_64-linux = pkgs.vmware-player-16;
  };
}
