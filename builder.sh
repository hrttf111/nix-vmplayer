source $stdenv/setup

echo "Start builder"

tar xzf $tarfile
curr=$(pwd)
export VMIS_TEMP=curr
