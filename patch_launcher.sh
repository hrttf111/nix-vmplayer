csplit launcher.sh "/.*extract_self$/1"

cat xx00 > launcher_patched.sh
cat >> launcher_patched.sh <<- EOM
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
   echo "Patch done"
EOM
cat xx01 >> launcher_patched.sh

rm xx0*
