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
   PYTHON_SO1=\$VMIS_TEMP/install/vmware-installer/python/libpython3.9.so.1.0

   patchelf --set-interpreter ${GLIBC_SO}/lib64/ld-linux-x86-64.so.2 \$VMIS_TEMP/install/vmware-installer/vmis-launcher
   #patchelf --replace-needed libpython3.9.so.1.0 ${PYTHON_SO}/lib/libpython3.9.so.1.0 \$VMIS_TEMP/install/vmware-installer/vmis-launcher
   patchelf --replace-needed libpython3.9.so.1.0 \${PYTHON_SO1} \$VMIS_TEMP/install/vmware-installer/vmis-launcher 

   ldd \$VMIS_TEMP/install/vmware-installer/vmis-launcher
   PYSO=\$VMIS_TEMP/install/vmware-installer/
   for so in \$(find \$PYSO -iname "*.so*"); do
      if [ -n "\$(file \$so | grep -i elf)" ]; then
          echo "Patch \$so"
          patchelf --replace-needed libncursesw.so.6 ${NCURSES_SO}/lib/libncursesw.so.6  \$so
          patchelf --replace-needed libreadline.so.6 ${READLINE_SO}/lib/libreadline.so.6  \$so
          patchelf --replace-needed libsqlite3.so.0 ${SQLITE_SO}/lib/libsqlite3.so.0  \$so
          patchelf --replace-needed libz.so.1 ${ZLIB_SO}/lib/libz.so.1  \$so
          patchelf --replace-needed libbz2.so.1.0 ${BZIP_SO}/lib/libbz2.so.1  \$so
          patchelf --replace-needed liblzma.so.5 ${LZMA_SO}/lib/liblzma.so.5 \$so
          patchelf --replace-needed libpython3.9.so.1.0 \${PYTHON_SO1} \$so
          #patchelf --replace-needed libpython3.9.so.1.0 ${PYTHON_SO}/lib/libpython3.9.so.1.0 \$so
          ldd \$so
      fi
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
