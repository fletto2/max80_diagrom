#!/usr/bin/env python3
"""Make the diagnostic boot disk.

Usage: python3 tools/mkdisk.py diag.sys OUT.imd [--525] [--bad0]

diag.sys is the boot sector and the program after it. The disk is one
sided with 512-byte sectors numbered from 0: 8-inch FM, 77 tracks of 8
sectors, 3:1 interleave, 308K, or with --525 MFM, 40 tracks of 9
sectors, 2:1 interleave, 180K. The boot ROM tries both densities, and
the boot sector reads the rest at the one the ROM found. Sector 1 holds
a copy of the boot sector, which the ROM runs when sector 0 cannot be
read. The program follows it in sector order, and the rest of
the disk holds E5h. --bad0, for the tests, writes sector 0 with a data
error.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'tools'))
from dmk2imd import write_imd  # noqa: E402

# tracks, sectors a track, the order of the sectors on the track
EIGHT = (77, 8, [i * 3 % 8 for i in range(8)])
FIVE = (40, 9, [i * 5 % 9 for i in range(9)])


def main():
    args = sys.argv[1:]
    five = '--525' in args
    if five:
        args.remove('--525')
    bad0 = '--bad0' in args
    if bad0:
        args.remove('--bad0')
    if len(args) != 2:
        raise SystemExit(__doc__)
    tracks, spt, order = FIVE if five else EIGHT
    sysimg = bytearray(open(args[0], 'rb').read())
    sysimg[2] = spt                     # bspt in src/boot.asm
    sysimg[512:512] = sysimg[:512]      # the boot sector's copy
    size = tracks * spt * 512
    if len(sysimg) > size:
        raise SystemExit('the program does not fit on the disk')
    disk = bytes(sysimg) + b'\xe5' * (size - len(sysimg))
    out = []
    for t in range(tracks):
        secs = []
        for r in order:
            off = (t * spt + r) * 512
            secs.append(dict(c=t, h=0, r=r, size=512, dd=five,
                             data=disk[off:off + 512], deleted=False,
                             bad=bad0 and t == 0 and r == 0))
        out.append((t, 0, secs))
    write_imd(out, args[1], not five, os.path.basename(args[0]),
              tool='diag/tools/mkdisk.py')


if __name__ == '__main__':
    main()
