# MAX-80 boot disk monitor

A machine code monitor on its own boot disk, with no OS. Use it to
look at RAM by hand, find bad RAM, and load small programs over the
serial port. It's about 9K with its font.

## Building

`make` needs sjasmplus and Python 3, and writes `build/monitor.imd`
(8-inch) and `build/monitor_525.imd` (5.25-inch 180K).
Write the disk image to a 5.25" or 8" disk and boot on your MAX-80.

## Using it

At boot it names itself and the build it is, the commit and the date
the disk was made, and the RAM it found:

    Lobo MAX-80 Monitor: Based on AGFA-MONITOR Build 9b89a03 10-Nov-2026
    128K RAM detected, banks: A1, A2, B1, B2

The console is the screen and keyboard, and SIO channel A at 9600, at
the same time. The prompt names the chunk the monitor runs in, `A1>` at
boot. `?` or `H` lists the commands. Numbers are hex. ESC or BREAK
stops a long command, from either console. A dead or missing SIO,
which reads FFh, is taken as nothing coming in, so the screen and
keyboard work alone. A terminal may end a line with CR LF.

An address is `1234`, a Z80 address through the map as it stands, or
`A2:1234`, an offset of 0000h to 7FFFh in chunk A1, A2, B1 or B2. The
chunk form reaches all of a chunk, the part under the I/O block too.

| Command | Does |
| --- | --- |
| `D addr [len]` | Dump, 21 lines a screen, or to the end of memory or the chunk. `D` alone goes on |
| `E addr` | Edit: hex and Enter writes and reads back, Enter alone goes on, a dot or ESC ends |
| `F addr len byte` | Fill |
| `M from to len` | Move, also between chunks and over itself. From a Z80 range across 8000h to a chunk address it says to move each side by itself |
| `S addr len bytes` | Search: hex bytes, a `"string"`, or both, up to 32 bytes. The first 16 places, then a count |
| `C addr addr len` | Compare: the first 16 differences, then a count |
| `K addr len` | An 8-bit sum and CRC-16/XMODEM |
| `G [addr]` | Go, a `RET` comes back, with the PIO put back as the monitor had it, and the block when the program left it at 0000h or F000h; a program that moves it anywhere else must put it back. The return writes VLATCH's RAM copy, 07DCh of the low chunk. Alone, the start an S-record file gave. A chunk address runs only where the map shows that chunk |
| `L` | Load S-records from channel A |
| `P addr len` | Punch S-records to channel A alone |
| `T addr len` | Test: 55h, AAh, 00h, FFh and the address, each written over all of it and read back. One pass |
| `I port`, `O port byte` | `IN` and `OUT` on an expansion bus port |
| `RUN chunk` | Move the monitor to a chunk and go on there |

On the keyboard, letters are lower case with SHIFT for upper, and
SHIFT gives the TRS-80 symbols on the digits and punctuation. Outside
quotes everything is taken as upper case.

`F`, `M`, `T`, `L` and `E` refuse the monitor's own memory: the program
from 1000h and 7000h-7FFFh of the chunk in the low half, and with the
monitor in A1, F400h-FBFFh, whose writes land there, and in any chunk
F7DCh-F7FDh, VLATCH to the PIO's control port A, which would map it out. A Z80 address
in the block at F000h says so and asks before a command goes on, since
reads reach the devices, and `E` asks again when it steps into the
block.

`L` takes S1 records, and S2 where 00000h-1FFFFh are the four chunks in
order, A1, A2, B1 and B2. S9 and S8 end it and give the start for `G`, an S8 start in a chunk
that is there. S0, S5 and S6 are skipped. Anything before the first
record is skipped, a banner, and an S with no type digit after it is a
word in it. After the first record only blanks and line ends: a record
whose S was lost stops the load at its line. Nothing
is shown and nothing is sent until the end. A bad line stops the load
with its number, and the rest of the file is waited out, not run as
commands, for up to 8K bytes. RTS is not used.

## Bad RAM in A1

`RUN A2` copies the monitor and goes on with A2 low and A1 high. It
checks the places it needs first. Then all of A1 can be tested with
`T A1:0 8000`.

Every write to the I/O block also lands in A1, and so does changing
the map. So a command maps once, then writes nothing to the block and
prints nothing until its loop ends. Between commands, a fill of A1
keeps all but 07DCh and 07FCh (the latches, block at 0000h), 77DCh
(the latch, block at F000h) and 77E4h (the serial copy).
The help gives a wider range.


## Files

- `src/mon.asm`: The top. `boot.asm`, `cons.asm`, `keys.asm`,
  `setup.asm` and `vars.inc` come from `../diag/src/`.
- `src/vars.inc`: The monitor's variables and buffers.
- `build/version.inc`: The build shown at boot, written by the
  `Makefile` from `git log` and the date.
- `src/main.asm`: Start, the command loop, the line editor, the parser
  and the map.
- `src/cmds.asm`: The commands.
- `src/srec.asm`: `L` and `P`.

## License

MIT, in `LICENSE`.
