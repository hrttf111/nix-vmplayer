### nix-vmplayer

This project contains a set of nix, bash and python scripts which create NIX derivation for VMware Player. It allows to run vmplayer GUI and VMs.
Note: In general these scripts allow to build and run VMware Workstation too, but since I have no licence I could only build it.
The project is not complete, this is just a proof of concept which allows to execute virtual machines in vmplayer. It has many limitations and problems:
 - There is no integration with nixos
 - The application needs to be executed with root privileges
 - It is required to manually load modules before starting VM
 - Kernel version needs to be manually set before building vmplayer
 - Only vmplayer is built, other tools are not functional
 - Only limited testing was conducted, not all virtualized drivers may be functional

VMware Player versions supported: 12, 14, 15, 16
Note: Take into account that older versions (for example, 12) may not run correctly on modern CPUs.

How to build and run:
 - Set correct kernel version to build compatible kernel modules in "flake.nix"
    - To make sure that you are using exactly same kernel version as your host, you may copy "/etc/nixos/flake.lock" to project dir
 - Configure correct vmplayer link (in default.nix) or use local bundle
    - To simplify debugging I am running local nginx server which allows nix to download vmplayer bundles from localhost
    - You need to download bundle manually and then put to a specific dir (make it public "0666"), by default it is "/opt/sandbox/public"
    - You may change default dir in "local-image.nix", see "defaultDataDir"
    - To run nginx execute "nix run ./#run-nginx" in a parallel terminal. You may stop it once vmplayer is built
 - Run "nix build ./#vmware-player-16.fhs"
 - Then enter fhs: "sudo result/bin/vmware-player-fhs-16.2.3"
    - vmplayer requires root privileges to run, so we need to enter as root
 - Run "copy_pref", it will create "~/.vmware" directory and copy default config there
    - Since you are entered fhs as root it will create config dir in "/root"
 - Run "ins_mods" to insert vmware kernel modules
 - Run "vmplayer"
