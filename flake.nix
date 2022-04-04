{
  description = "vmware player try";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-21.11";
  };

  outputs = { self, nixpkgs }:
  let
    version = "16.2.3";
    pkgs = nixpkgs.legacyPackages.x86_64-linux.pkgs;
    kernel = nixpkgs.legacyPackages.x86_64-linux.pkgs.linux_5_15;

    bundle = pkgs.fetchurl {
      #url = "https://download3.vmware.com/software/player/file/VMware-Player-14.1.7-12989993.x86_64.bundle";
      #url = "https://download3.vmware.com/software/player/file/VMware-Player-12.5.9-7535481.x86_64.bundle";
      #url = "http://127.0.0.1/public/VMware-Player-12.5.9-7535481.x86_64.bundle";
      url = "http://127.0.0.1/public/VMware-Player-Full-16.2.3-19376536.x86_64.bundle";
      #sha256 = "2a967fe042c87b7a774ba1d5a7d63ee64f34b5220bf286370ca3439fed60487a";
      sha256 = "2c320084765b7a4cd79b6a0e834a6d315c4ecd61d0cc053aa7a445a7958738b0";
    };

    vmware-bundle = import ./bundle { inherit pkgs; originalBundle = bundle; inherit version; };
    vmware-vmx = import ./vmx { inherit pkgs; inherit vmware-bundle; inherit version; };

    vmware-kernel = pkgs.stdenv.mkDerivation rec {
      pname = "vmware-kernel";
      inherit version;
      src = ./.;

      hardeningDisable = [ "all" ];
      buildInputs = with pkgs; [ gcc gnumake vmware-bundle tree patch ];
      nativeBuildInputs = kernel.moduleBuildDependencies;
      makeFlags = [
        "KVERSION=${kernel.modDirVersion}"
        "LINUXINCLUDE=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/"
        "VM_KBUILD=yes"
      ];
      #patches = [ ./vmmon.patch ];

      unpackPhase = ''
      '';

      buildPhase = ''
        tar xf "${vmware-bundle}/vmware-vmx/lib/modules/source/vmmon.tar"
        cp -r ./vmmon-only ./vmmon
        ${pkgs.patch}/bin/patch -p1 < $src/vmmon.patch
        export KVERSION=${kernel.modDirVersion}
        export LINUXINCLUDE=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/
        export VM_KBUILD=yes
        make -C ./vmmon
      '';

      installPhase = ''
        tree $src
        binDir="$out/lib/modules/${kernel.modDirVersion}/kernel/"
        mkdir -p $binDir
        cp ./vmmon/*.ko $binDir
      '';

      shellHook = ''
        export KVERSION=${kernel.modDirVersion}
        export LINUXINCLUDE=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build/include/
        export VM_KBUILD=yes
      '';
    };

    vmware-config = pkgs.stdenv.mkDerivation rec {
      pname = "vmware-config";
      inherit version;
      buildInputs = with pkgs; [ vmware-vmx vmware-kernel vmware-bundle ];

      src = ./.;

      installPhase = ''
        set -x
        mkdir -p $out/{etc,home,root,usr,bin}
        ln -s ${vmware-vmx}/usr/lib/vmware/bin/vmplayer $out/bin/vmplayer
        mkdir $out/etc/vmware
        cp $src/vmware-config $out/etc/vmware/config
        cp $src/vmware-config-bootstrap $out/etc/vmware/bootstrap
        #VMWARE_DIR=${placeholder "out"}
        VMWARE_DIR=${vmware-vmx}
        sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/vmware/bootstrap"
        sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/vmware/config"
        mkdir $out/etc/gtk-2.0
        cp $src/local_conf/etc/gtk-2.0/* $out/etc/gtk-2.0/
        sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/gtk-2.0/gdk-pixbuf.loaders"
        sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/gtk-2.0/gtk.immodules"
        mkdir $out/etc/pango
        cp $src/local_conf/home/pangox.aliases $out/etc/
        cp $src/local_conf/home/pango.modules $out/etc/
        cp $src/local_conf/home/pangorc $out/etc/pango/
        sed -i "s,@@VMWARE_DIR@@,$VMWARE_DIR," "$out/etc/pango.modules"
        cp $src/local_conf/home/vmware/preferences $out/etc/vmware/preferences
        echo 'mkdir ~/.vmware; cp /etc/vmware/preferences ~/.vmware/' > $out/bin/copy_pref
        chmod +x $out/bin/copy_pref
        echo "modprobe vmw_vmci; insmod ${vmware-kernel}/lib/modules/${kernel.modDirVersion}/kernel/vmmon.ko" > $out/bin/ins_mods
        chmod +x $out/bin/ins_mods
        #lib.getLib pcsclite
        ln -s ${vmware-vmx}/usr/lib/vmware/icu $out/etc/vmware/icu
      '';
    };

    vmware-player-fhs = pkgs.buildFHSUserEnv {
      pname = "vmware-player-fhs";
      inherit version;

      targetPkgs = pkgs: with self.pkgs; [
        vmware-config
        vmware-vmx
        vmware-kernel
      ];

      profile = ''
        export VMWARE_VMX=${vmware-vmx}
        export VMWARE_CONFIG=${vmware-config}
        export VMWARE_KERNEL=${vmware-kernel}
        export VMWARE_BUNDLE=${vmware-bundle}
      '';

      extraBuildCommands = ''
      '';

      extraInstallCommands = ''
      '';

      runScript = "bash -l";
    };
  in
  {
    inherit vmware-bundle;
    inherit vmware-vmx;
    inherit vmware-kernel;
    inherit vmware-player;

    overlay = final: prev: {
      vmware-player = vmware-player-fhs;
      #vmware-player = vmware-bundle;
      #vmware-player = vmware-vmx;
    };
    defaultPackage.x86_64-linux = vmware-player-fhs;
  };
}
