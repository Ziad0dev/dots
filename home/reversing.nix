# Reverse engineering on the desktop: the infosec toolkit's binary/pwn sets
# (radare2 + iaito, rizin with rz-ghidra, Ghidra, GDB + GEF, ImHex,
# pwntools, ROPgadget, …) and a radare2 config whose colours follow themectl.
{ config, ... }:
{
  zi.infosec.sets = [
    "binary"
    "pwn"
  ];

  home.file.".radare2rc".text = ''
    e cfg.fortunes = false
    e scr.color = 3
    e scr.utf8 = true
    e scr.utf8.curvy = true
    e scr.wheel = true
    e asm.describe = false
    e asm.bytes = false
    e bin.relocs.apply = true
    e scr.hist.save = true
    # palette rendered by themectl (config/themes/_templates/radare2.in)
    . ${config.xdg.stateHome}/dots/theme/radare2
  '';
}
