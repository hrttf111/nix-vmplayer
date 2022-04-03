SRC=result/
libs=$(find $SRC -iname "*.so*" | xargs ldd 2> /dev/null | grep -i "not found" | sort | uniq | awk -s '{ print $1; }' | grep -v "\/")
#echo $libs
#DEST=${placeholder "out"}/usr/lib/vmware/lib
DEST=/
for lib in $libs; do
    res=$(find result/ -iname "$lib")
    if [ -z "$res" ]; then
        echo "Not found: $lib"
    else
        echo "Found: $lib"
        libPath=$(echo $res | awk -s '{ print $1; }')
        if [ -n "$(file $libPath | grep -i elf)" ]; then
            libPath=$libPath
        elif [ -n "$(file $libPath/$lib | grep -i elf)" ]; then
            libPath=$libPath/$lib
        else
            echo "Unknown lib $lib -> $libPath"
            continue
        fi
        echo " - $libPath"
        echo "patchelf --replace-needed $lib $DEST/$libPath \$elf"
    fi
done
