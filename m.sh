F=VMware-Player-12.5.9-7535481.x86_64.bundle

FILE_SIZE=`stat --format "%s" "$F"`
offset=$(($FILE_SIZE - 4))

MAGIC_OFFSET=$offset
offset=$(($offset - 4))

CHECKSUM_OFFSET=$offset
offset=$(($offset - 4))

VERSION_OFFSET=$offset
offset=$(($offset - 4))

PREPAYLOAD_OFFSET=$offset
offset=$(($offset - 4))

PREPAYLOAD_SIZE_OFFSET=$offset
offset=$(($offset - 4))

LAUNCHER_SIZE_OFFSET=$offset
offset=$(($offset - 4))

PAYLOAD_OFFSET=$offset
offset=$(($offset - 4))

PAYLOAD_SIZE_OFFSET=$offset
offset=$(($offset - 4))

file=$F

MAGIC_NUMBER=`od -An -t u4 -N 4 -j $MAGIC_OFFSET "$file" | tr -d ' '`
echo "Magic offset = ${MAGIC_OFFSET}"
echo "LAUNCHER_SIZE_OFFSET = $LAUNCHER_SIZE_OFFSET"
echo "Magic num = $MAGIC_NUMBER"
echo "PAYLOAD_OFFSET=${PAYLOAD_OFFSET}"
echo "PAYLOAD_SIZE_OFFSET=${PAYLOAD_SIZE_OFFSET}"

if [ "$MAGIC_NUMBER" != "907380241" ]; then
  echo "magic number does not match"
  exit 1
fi

LAUNCHER_SIZE=`od -An -t u4 -N 4 -j $LAUNCHER_SIZE_OFFSET "$file" | tr -d ' '`
PAYLOAD_SIZE=`od -An -t u4 -N 4 -j $PAYLOAD_SIZE_OFFSET "$file" | tr -d ' '`
PREPAYLOAD_SIZE=`od -An -t u4 -N 4 -j $PREPAYLOAD_SIZE_OFFSET "$file" | tr -d ' '`

SKIP_BYTES=$(($PREPAYLOAD_SIZE + $LAUNCHER_SIZE))

echo "LAUNCHER_SIZE=$LAUNCHER_SIZE"
echo "PAYLOAD_SIZE=$PAYLOAD_SIZE"
echo "PREPAYLOAD_SIZE=$PREPAYLOAD_SIZE"

#LAUNCHER_SIZE=15894
dd if="$file" ibs=$LAUNCHER_SIZE obs=1 count=1 of=launcher.sh
