import struct
import sys
import argparse
from binascii import crc32


class BundleFooter:
    MAGIC_NUMBER     = 0x36158611
    FOOTER_FORMAT    = '=QIIIIIIIIIII'
    FOOTER_SIZE      = struct.calcsize(FOOTER_FORMAT)
    DEFAULT_TPL      = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

    def __init__(self, tpl=DEFAULT_TPL):
        if len(tpl) != len(BundleFooter.DEFAULT_TPL):
            raise Exception(f"Wrong footer tuple length {len(tpl)}")
        self.data_size = tpl[0]
        self.data_offset = tpl[1]
        self.manifest_size = tpl[2]
        self.manifest_offset = tpl[3]
        self.payload_size = tpl[4]
        self.payload_offset = tpl[5]
        self.launcher_size = tpl[6]
        self.pre_size = tpl[7]
        self.pre_offset = tpl[8]
        self.version = tpl[9]
        self.checksum = tpl[10]
        self.magic_number = tpl[11]

    def pack(self):
        return struct.pack(BundleFooter.FOOTER_FORMAT
                           , self.data_size
                           , self.data_offset
                           , self.manifest_size
                           , self.manifest_offset
                           , self.payload_size
                           , self.payload_offset
                           , self.launcher_size
                           , self.pre_size
                           , self.pre_offset
                           , self.version
                           , self.checksum
                           , self.magic_number)

    def calc_checksum(self):
        footer_bytes = self.pack()
        return crc32(footer_bytes[0:-8]) & 0xffffffff

    def is_magic_valid(self):
        return self.magic_number == BundleFooter.MAGIC_NUMBER

    def is_checksum_valid(self):
        checksum = self.calc_checksum()
        return self.checksum == checksum

    @staticmethod
    def unpack(footer_bytes):
        tpl = struct.unpack(BundleFooter.FOOTER_FORMAT, footer_bytes)
        return BundleFooter(tpl)

    @staticmethod
    def read_footer(fd):
        fd.seek(0, 2)
        file_size = fd.tell()
        fd.seek(-BundleFooter.FOOTER_SIZE, 2)
        header = fd.read(BundleFooter.FOOTER_SIZE)
        return BundleFooter.unpack(header)

    def __repr__(self):
        return f"""
magic_number = {self.magic_number}
checksum = {self.checksum}
version = {self.version}
pre_offset = {self.pre_offset}
pre_size = {self.pre_size}
launcher_size = {self.launcher_size}
payload_offset = {self.payload_offset}
payload_size = {self.payload_size}
manifest_offset = {self.manifest_offset}
manifest_size = {self.manifest_size}
data_offset = {self.data_offset}
data_size = {self.data_size}
---
payload_offset + payload_size = {self.payload_offset + self.payload_size}
manifest_offset + manifest_size = {self.manifest_offset + self.manifest_size}
        """


def extract_launcher(bundle_path, launcher_path, debug):
    with open(bundle_path, 'rb') as bundle:
        footer = BundleFooter.read_footer(bundle)

        if debug:
            print(f"{footer}")

        if not footer.is_magic_valid():
            raise Exception("Magic number is not valid" % footer.magic_number)

        if not footer.is_checksum_valid():
            raise Exception("Checksum is invalid %d != %d" % (footer.calc_checksum(), footer.checksum))

        bundle.seek(footer.manifest_offset)
        manifest = bundle.read(footer.manifest_size)
        if len(manifest) != footer.manifest_size:
            raise Exception('Manifest cannot be read %d != %d' % (len(manifest), footer.manifest_size))

        if debug:
            print('Manifest: {}'.format(manifest))

        with open(launcher_path, 'wb') as launcher_file:
            bundle.seek(0, 0)
            launcher = bundle.read(footer.launcher_size)
            launcher_file.write(launcher)


def replace_launcher(bundle_path, launcher_path, new_bundle_path, debug):
    with open(launcher_path, 'rb') as launcher_fd:
        launcher_patched = launcher_fd.read(-1)
        launcher_patched_size = launcher_fd.tell()

    with open(bundle_path, 'rb') as bundle, \
        open(new_bundle_path, 'wb') as new_bundle:
        new_bundle.write(launcher_patched)

        footer = BundleFooter.read_footer(bundle)
        bundle.seek(0, 2)
        file_size = bundle.tell()

        bundle.seek(footer.payload_offset, 0)
        to_read = file_size - footer.pre_size - BundleFooter.FOOTER_SIZE
        data = bundle.read(to_read)
        new_bundle.write(data)

        footer.pre_offset = launcher_patched_size
        footer.launcher_size = launcher_patched_size
        footer.payload_offset = launcher_patched_size
        footer.manifest_offset = footer.payload_offset + footer.payload_size + 1
        footer.data_offset = footer.manifest_offset + footer.manifest_size
        footer.checksum = footer.calc_checksum()

        if debug:
            print(footer)

        new_bundle.write(footer.pack())


def __main__():
    parser = argparse.ArgumentParser(description='VMWare bundle packaging tool')
    parser.add_argument('--bundle', dest='bundle', action='store', type=str, required=True,
                        help='Path to original bundle')
    parser.add_argument('--launcher', dest='launcher', action='store', type=str, required=True,
                        help='Path to launcher (patched or original)')
    parser.add_argument('--new-bundle', dest='new_bundle', action='store', type=str,
                        help='Path to new bundle created by this application')
    parser.add_argument('--action', dest='action', choices=['extract', 'replace'], required=True,
                        help='Extract launcher from bundle or create new bundle with new launcher')
    parser.add_argument('--debug', dest='debug', action='store_true',
                        help='Enable debug print')
    args = parser.parse_args()

    if args.action == 'extract':
        extract_launcher(args.bundle, args.launcher, args.debug)
    elif args.action == 'replace':
        if not args.new_bundle:
            print("Cannot replace without valid new-bundle path")
            exit(1)
        replace_launcher(args.bundle, args.launcher, args.new_bundle, args.debug)

if __name__ == '__main__':
    __main__()
