SRC=result/
files=$(find $SRC -iname "*")
bins=
for f in $files; do
    if [ -n "$(file $f | grep -i elf)" ]; then
        bins="$bins $f"
    fi
done
#libs=$(find $SRC -iname "*.so*" | xargs ldd 2> /dev/null | grep -i "not found" | sort | uniq | awk -s '{ print $1; }' | grep -v "\/")
libs=$(echo $bins | xargs ldd 2> /dev/null | grep -i "not found" | sort | uniq | awk -s '{ print $1; }' | grep -v "\/")
DEST=/
rm patches
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
        echo "patchelf --replace-needed $lib $DEST/$libPath" >> patches
    fi
done

rm bin_patches
for bin in $bins; do
    ulibs=$(ldd $bin 2> /dev/null | grep -i "not found" | sort | uniq | awk -s '{ print $1; }' | grep -v "\/")
    for ulib in $ulibs; do
        p=$(cat patches | grep "$ulib")
        if [ -n "$p" ]; then
            echo "$p $bin" >> bin_patches
        fi
    done
done
