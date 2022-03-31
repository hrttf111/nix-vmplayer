csplit launcher.sh "/.*extract_self$/1"

set -x

#echo "${BASH_SH}" > launcher_patched.sh
#cp $(cat $stdenv/setup | grep "[^ ]*shebangs.sh" -o) patchShebangs.sh
#sed -i "s/fixupOutputHooks.*$//" patchShebangs.sh
#stopNest() { true; }
#source ./patchShebangs.sh
#sed -i "1s/^/${BASH_SH} /" launcher_patched.sh
#source /nix/store/bnj8d7mvbkg3vdb07yz74yhl3g107qq5-patch-shebangs.sh

escapedInterpreterLine=${BASH_SH//\\/\\\\}

cat xx00 >> launcher_patched.sh
cat >> launcher_patched.sh <<- EOM
   #source $stdenv/setup
   source $(cat $stdenv/setup | grep "[^ ]*shebangs.sh" -o)
   echo "Patch ELF"
   patchelf --set-interpreter ${GLIBC_SO}/lib64/ld-linux-x86-64.so.2 \$VMIS_TEMP/install/vmware-installer/vmis-launcher
   PYSO=\$VMIS_TEMP/install/vmware-installer/python/lib/lib-dynload/
   for so in \${PYSO}/*.so; do
      echo "Patch \$so"
      patchelf --replace-needed libpython2.7.so.1.0 ${PYTHON_SO}/lib/libpython2.7.so.1.0  \$so
      patchelf --replace-needed libncursesw.so.5 ${NCURSES_SO}/lib/libncursesw.so.5  \$so
      patchelf --replace-needed libsqlite3.so.0 ${SQLITE_SO}/lib/libsqlite3.so.0  \$so
      patchelf --replace-needed libz.so.1 ${ZLIB_SO}/lib/libz.so.1  \$so
   done
   echo "Patch shebang"
   sed -i -e "1 s|.*|#\!$escapedInterpreterLine|" \$VMIS_TEMP/install/vmware-installer/vmware-installer
   #patchShebangs \$VMIS_TEMP
   #sed -i '1s/^/${BASH_SH}/' \$VMIS_TEMP/install/vmware-installer/vmware-installer
   echo "Patch done"
EOM
cat xx01 >> launcher_patched.sh

sed -i 's/set -e/set -e\nset -x/' launcher_patched.sh

sed -i -e "1 s|.*|#\!$escapedInterpreterLine|" launcher_patched.sh
#patchShebangs --build launcher_patched.sh

rm xx0*
