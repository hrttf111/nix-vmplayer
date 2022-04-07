bundleSource=$1
pkgdir=$2
extraConfig=$3

vmware_installer_version=$(cat "${bundleSource}/vmware-installer/manifest.xml" | grep -oPm1 "(?<=<version>)[^<]+")

_isoimages=(linux linuxPreGlibc25 netware solaris windows winPre2k winPreVista)
_isovirtualprinterimages=(Linux Windows)

mkdir -p \
  "$pkgdir/etc"/{cups,pam.d,modprobe.d,thnuclnt,vmware} \
  "$pkgdir/usr"/{share,bin} \
  "$pkgdir/usr/include/vmware-vix" \
  "$pkgdir/usr/lib"/{vmware/setup,vmware-vix,vmware-ovftool,vmware-installer/"$vmware_installer_version",cups/filter,modules-load.d} \
  "$pkgdir/usr/share"/{doc/vmware-vix,licenses/"$pkgname"} \
  "$pkgdir/var/lib/vmware/Shared VMs"

chmod +w -R $pkgdir/*

rsync --chmod=+w -r \
  $bundleSource/vmware-player/share/* \
  $bundleSource/vmware-player-app/share/* \
  "$pkgdir/usr/share"

rsync --chmod=+w -r \
  $bundleSource/vmware-vmx/{,s}bin/* \
  $bundleSource/vmware-player-app/bin/* \
  "$pkgdir/usr/bin"

rsync --chmod=+w -r \
  $bundleSource/vmware-player/lib/* \
  $bundleSource/vmware-player-app/lib/* \
  $bundleSource/vmware-vmx/{lib/*,roms} \
  $bundleSource/vmware-usbarbitrator/bin \
  $bundleSource/vmware-network-editor/lib \
  "$pkgdir/usr/lib/vmware"

rsync --chmod=+w -r \
  $bundleSource/vmware-player-setup/vmware-config \
  "$pkgdir/usr/lib/vmware/setup"

rsync --chmod=+w -r \
  $bundleSource/vmware-ovftool/* \
  "$pkgdir/usr/lib/vmware-ovftool"

rsync --chmod=+w -r \
  $bundleSource/vmware-installer/{python,sopython,vmis,vmis-launcher,vmware-installer,vmware-installer.py} \
  "$pkgdir/usr/lib/vmware-installer/$vmware_installer_version"

rsync --chmod=+w -r \
  $bundleSource/vmware-player-app/etc/cups/* \
  "$pkgdir/etc/cups"

rsync --chmod=+w -r \
  $bundleSource/vmware-player-app/extras/thnucups \
  "$pkgdir/usr/lib/cups/filter"

for isoimage in ${_isoimages[@]}
do
  install -Dm 644 "$bundleSource/vmware-tools-$isoimage/$isoimage.iso" "$pkgdir/usr/lib/vmware/isoimages/$isoimage.iso"
done

for isoimage in ${_isovirtualprinterimages[@]}
do
  install -Dm 644 "$bundleSource/vmware-virtual-printer/VirtualPrinter-$isoimage.iso" "$pkgdir/usr/lib/vmware/isoimages/VirtualPrinter-$isoimage.iso"
done

install -Dm 644 "$bundleSource/vmware-player/doc/EULA" "$pkgdir/usr/share/doc/vmware-player/EULA"
install -Dm 644 "$bundleSource/vmware-player/doc/EULA" "$pkgdir/usr/share/licenses/vmware-player/VMware Workstation - EULA.txt"
install -Dm 644 "$pkgdir/usr/lib/vmware-ovftool/vmware.eula" "$pkgdir/usr/share/licenses/vmware-player/VMware OVF Tool - EULA.txt"
install -Dm 644 "$bundleSource/vmware-player-app/doc"/open_source_licenses.txt "$pkgdir/usr/share/licenses/vmware-player/VMware Workstation open source license.txt"
install -Dm 644 "$bundleSource/vmware-player-app/doc"/ovftool_open_source_licenses.txt "$pkgdir/usr/share/licenses/vmware-player/VMware OVF Tool open source license.txt"
#install -Dm 644 "$bundleSource/vmware-vix-core"/open_source_licenses.txt "$pkgdir/usr/share/licenses/vmware-player/VMware VIX open source license.txt"
rm "$pkgdir/usr/lib/vmware-ovftool"/{vmware-eula.rtf,open_source_licenses.txt,manifest.xml}

install -Dm 644 "$bundleSource/vmware-vmx/etc/modprobe.d/modprobe-vmware-fuse.conf" "$pkgdir/etc/modprobe.d/vmware-fuse.conf"

install -Dm 644 $bundleSource/vmware-vmx/extra/modules.xml "$pkgdir"/usr/lib/vmware/modules/modules.xml
install -Dm 644 $bundleSource/vmware-installer/bootstrap "$pkgdir"/etc/vmware-installer/bootstrap

rm -r "$pkgdir/usr/lib/vmware/xkeymap" # these files are provided by vmware-keymaps package

chmod +x \
  "$pkgdir/usr/bin"/* \
  "$pkgdir/usr/lib/vmware/bin"/* \
  "$pkgdir/usr/lib/vmware/setup"/* \
  "$pkgdir/usr/lib/vmware-ovftool"/{ovftool,ovftool.bin} \
  "$pkgdir/usr/lib/vmware-installer/$vmware_installer_version"/{vmware-installer,vmis-launcher} \
  "$pkgdir/usr/lib/cups/filter"/*

#chmod +s \
#  "$pkgdir/usr/bin"/{vmware-authd,vmware-mount} \
#  "$pkgdir/usr/lib/vmware/bin"/{vmware-vmx,vmware-vmx-debug,vmware-vmx-stats}

for link in \
  licenseTool \
  vmplayer \
  vmware \
  vmware-app-control \
  vmware-enter-serial \
  vmware-fuseUI \
  vmware-gksu \
  vmware-modconfig \
  vmware-modconfig-console \
  vmware-netcfg \
  vmware-tray \
  vmware-unity-helper \
  vmware-vmblock-fuse \
  vmware-zenity
do
  ln -s $pkgdir/usr/lib/vmware/bin/appLoader "$pkgdir/usr/lib/vmware/bin/$link"
done


# create symlinks (replicate installer) - misc
ln -s $pkgdir/lib/vmware/icu $pkgdir/etc/vmware/icu
#ln -s $out/lib/vmware/lib/diskLibWrapper.so/diskLibWrapper.so $out/lib/diskLibWrapper.so
#ln -s $out/lib/vmware/lib/libvmware-hostd.so/libvmware-hostd.so $out/lib/vmware/lib/libvmware-vim-cmd.so/libvmware-vim-cmd.so
#ln -s $out/lib/vmware-ovftool/ovftool $out/bin/ovftool

# create database of vmware guest tools (avoids vmware fetching them later)
database_filename=$pkgdir/etc/vmware-installer/database
echo -n "" > $database_filename
sqlite3 "$database_filename" "CREATE TABLE settings(key VARCHAR PRIMARY KEY, value VARCHAR NOT NULL, component_name VARCHAR NOT NULL);"
sqlite3 "$database_filename" "INSERT INTO settings(key,value,component_name) VALUES('db.schemaVersion','2','vmware-installer');"
sqlite3 "$database_filename" "CREATE TABLE components(id INTEGER PRIMARY KEY, name VARCHAR NOT NULL, version VARCHAR NOT NULL, buildNumber INTEGER NOT NULL, component_core_id INTEGER NOT NULL, longName VARCHAR NOT NULL, description VARCHAR, type INTEGER NOT NULL);"
#for isoimage in linux linuxPreGlibc25 netware solaris windows winPre2k winPreVista; do
#        local iso_version=$(cat vmware-tools-$isoimage/manifest.xml | grep -oPm1 "(?<=<version>)[^<]+")
#  sqlite3 "$database_filename" "INSERT INTO components(name,version,buildNumber,component_core_id,longName,description,type) VALUES(\"vmware-tools-$isoimage\",\"$iso_version\",\"${version}\",1,\"$isoimage\",\"$isoimage\",1);"
#done

for isoimage in ${_isoimages[@]}
do
  version=$(cat "$bundleSource/vmware-tools-$isoimage/manifest.xml" | grep -oPm1 "(?<=<version>)[^<]+")
  sqlite3 "$database_filename" "INSERT INTO components(name,version,buildNumber,component_core_id,longName,description,type) VALUES(\"vmware-tools-$isoimage\",\"$version\",\"${vmware_installer_version#*_}\",1,\"$isoimage\",\"$isoimage\",1);"
done

install -m644 $extraConfig/vmware-config-bootstrap "$pkgdir"/etc/vmware/bootstrap
install -Dm 644 $extraConfig/vmware-config "$pkgdir"/etc/vmware/config
install -Dm 644 $bundleSource/vmware-installer/bootstrap "$pkgdir"/etc/vmware-installer/bootstrap
