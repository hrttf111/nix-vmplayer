SRC=$1
DEST=$2

if [ -z "$SRC" ]; then
    SRC=result/
    rm patches
fi

echo "SRC=$SRC DEST=$DEST"

rm execs
files=$(find $SRC -iname "*")
bins=
for f in $files; do
    if [ -n "$(file $f | grep -i elf)" ]; then
        bins="$bins $f"
        if [ -n "$(file $f | grep -i exe)" ]; then
            echo $f >> execs
        fi
    fi
done

libs=$(echo $bins | xargs ldd 2> /dev/null | grep -i "not found" | sort | uniq | awk -s '{ print $1; }' | grep -v "\/")
for lib in $libs; do
    res=$(find $SRC -iname "$lib")
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
        echo "patchelf --replace-needed $lib ${DEST}${libPath}" >> patches
    fi
done

rm bin_patches
rm not_found
for bin in $bins; do
    ulibs=$(ldd $bin 2> /dev/null | grep -i "not found" | sort | uniq | awk -s '{ print $1; }' | grep -v "\/")
    for ulib in $ulibs; do
        p=$(cat patches | grep "$ulib")
        if [ -n "$p" ]; then
            echo "$p $bin" >> bin_patches
        else
            echo "Cannot find \"$ulib\" for \"$bin\"" >> not_found
        fi
    done
done
chmod +x bin_patches
