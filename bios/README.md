
This BIOS is an open source replacement for Nintendo's official BIOS.
It was written originally by Normmatt and the VBA/VBA-M team, and its source
code can be found at https://github.com/Nebuleon/ReGBA/tree/master/bios

It is distributed under the GPL2 license (see repo)

## G&W / gpSP notes

`open_gba_bios.bin` in this directory is the binary linked into the firmware
(via `gba_bios.S` / the Linux harness). Rebuild with DEVKITARM when you change
`source/`; until then the checked-in `.bin` is authoritative.

Fixes applied on top of Normmatt's BIOS for Minish Cap (and similar):
- SWI System-mode frame is `{r2, lr}` like the official BIOS (not `{r2,r3,lr}`).
- `IntrWait` / `VBlankIntrWait` are assembly matching the official algorithm;
  the old C versions could wait forever after a miscompiled discard check.

