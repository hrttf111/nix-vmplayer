import struct
from binascii import crc32

MAGIC_NUMBER     = 0x36158611
FOOTER_FORMAT    = '=QIIIIIIIIIII'
FOOTER_SIZE      = struct.calcsize(FOOTER_FORMAT)

def CalculateChecksum(header):
    return crc32(header) & 0xffffffff # XXX: Python bug 1202

FILE_PATH = "/home/ddd/VMware-Player-12.5.9-7535481.x86_64.bundle"

source = open(FILE_PATH, 'rb')

source.seek(0, 2)
file_size = source.tell()

source.seek(-FOOTER_SIZE, 2)
header = source.read(FOOTER_SIZE)

try:
    dataSize, dataOffset, manifestSize, manifestOffset, payloadSize, payloadOffset, \
        launcherSize, presize, preoffset, version, checksum, magicNumber = \
        struct.unpack(FOOTER_FORMAT, header)
except struct.error:
    raise Exception("Error")

text = f"""
    magicNumber = {magicNumber}
    checksum = {checksum}
    version = {version}
    preoffset = {preoffset}
    presize = {presize}
    launcherSize = {launcherSize}
    payloadOffset = {payloadOffset}
    payloadSize = {payloadSize}
    manifestOffset = {manifestOffset}
    manifestSize = {manifestSize}
    dataOffset = {dataOffset}
    dataSize = {dataSize}

    payloadOffset + payloadSize = {payloadOffset + payloadSize}
    manifestOffset + manifestSize = {manifestOffset + manifestSize}
"""
print(text)

if magicNumber != MAGIC_NUMBER:
    raise Exception('Magic number of %#x does not match' % magicNumber)

calcChecksum = CalculateChecksum(header[0:-8])
if calcChecksum != checksum:
    raise Exception('Calculated checksum %d does not match expected %d' % \
                   (calcChecksum, checksum))

source.seek(manifestOffset)
manifest = source.read(manifestSize)
if len(manifest) != manifestSize:
    raise Exception('Unable to read manifest')

print('Loaded bundle manifest: {}'.format(manifest))

with open("launcher.sh", 'wb') as launcher_file:
    source.seek(0, 0)
    launcher = source.read(launcherSize)
    launcher_file.write(launcher)

with open("data", 'wb') as data_file:
    source.seek(payloadOffset, 0)
    to_read = file_size - presize - FOOTER_SIZE
    data = source.read(to_read)
    data_file.write(data)

with open("footer", 'wb') as footer_file:
    footer = struct.pack(FOOTER_FORMAT, \
        dataSize, dataOffset, manifestSize, manifestOffset, payloadSize, payloadOffset, \
        launcherSize, presize, preoffset, version, checksum, magicNumber)
    footer_file.write(footer)
