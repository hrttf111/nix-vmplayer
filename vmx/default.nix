{ pkgs, version, vmware-bundle, debug ? true }:

pkgs.stdenv.mkDerivation {
  pname = "vmware-vmx";
  inherit version;
  src = ./.;

  buildInputs = with pkgs; [
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

  installPhase = ''
    mkdir $out

    ./install.sh "${vmware-bundle}" $out $src

    echo "patchelf --replace-needed libcups.so.2 ${pkgs.cups.out}/lib/libcups.so.2" > patches
    echo "patchelf --replace-needed libuuid.so.1 ${pkgs.libuuid.lib}/lib/libuuid.so.1" >> patches

    ./find_lib.sh "$out"

    echo "Start patching"
    ./bin_patches
    for filename in $(cat execs); do
      if [ -n "$(${pkgs.file}/bin/file $filename | grep -i elf)" ]; then
        patchelf --set-interpreter ${pkgs.glibc}/lib64/ld-linux-x86-64.so.2 $filename
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
}
