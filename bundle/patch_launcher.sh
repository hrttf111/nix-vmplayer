LAUNCHER=$1
GLIBC_PATH=$2
PATCHES=$3
DEBUG=$4

csplit $LAUNCHER "/.*extract_self$/1"

if [ -n "$DEBUG" ]; then
    set -x
fi

escapedInterpreterLine=${shell//\\/\\\\}

patchText=$(cat $PATCHES)

cat xx00 >> launcher_patched.sh
cat >> launcher_patched.sh <<- EOM
   echo "Patch ELF"
   VMIS_LAUNCHER_PATH=\$VMIS_TEMP/install/vmware-installer/vmis-launcher

   patchelf --set-interpreter ${GLIBC_PATH}/lib64/ld-linux-x86-64.so.2 \$VMIS_TEMP/install/vmware-installer/vmis-launcher

   PYSO=\$VMIS_TEMP/install/vmware-installer/
   for so in \$(find \$PYSO -iname "*.so*") \$VMIS_LAUNCHER_PATH; do
      if [ -n "\$(file \$so | grep -i elf)" ]; then
          echo "Patch \$so"
          ${patchText}
      fi
   done

   echo "Patch shebang"
   sed -i -e "1 s|.*|#\!$escapedInterpreterLine|" \$VMIS_TEMP/install/vmware-installer/vmware-installer
   echo "Patch done"
EOM
cat xx01 >> launcher_patched.sh

if [ -n "$DEBUG" ]; then
    sed -i 's/set -e/set -e\nset -x/' launcher_patched.sh
fi

sed -i -e "1 s|.*|#\!$escapedInterpreterLine|" launcher_patched.sh

rm xx0*
mv launcher_patched.sh $LAUNCHER

if [ -n "$DEBUG" ]; then
    set +x
fi
