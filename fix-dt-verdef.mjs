/**
 * Repoint DT_VERDEF at the current `.gnu.version_d` address in a compiled ELF.
 *
 * patchelf relocates the dynamic-section cluster when it has to grow
 * `.dynamic` (setting an RPATH or adding a DT_NEEDED) but leaves DT_VERDEF
 * holding the pre-relocation address. glibc then follows a stale pointer in
 * `_dl_check_map_versions` and the binary SIGSEGVs before `main()` runs.
 *
 * Bun's compiled binaries define their own symbol versions, so this affects
 * them specifically. Must run after the last patchelf invocation.
 *
 * ELF64 little-endian only. Binaries without `.gnu.version_d` are a no-op.
 */

import * as fs from "node:fs";

const DT_NULL = 0n;
const DT_VERDEF = 0x6ffffffcn;
const SHT_DYNAMIC = 6;
const SHT_GNU_VERDEF = 0x6ffffffd;

function repair(path) {
  const fd = fs.openSync(path, "r+");
  try {
    const header = Buffer.alloc(64);
    fs.readSync(fd, header, 0, 64, 0);
    if (header.toString("latin1", 0, 4) !== "\x7fELF") {
      throw new Error(`${path}: not an ELF file`);
    }
    if (header[4] !== 2 || header[5] !== 1) {
      throw new Error(`${path}: not ELF64 little-endian`);
    }

    const shoff = Number(header.readBigUInt64LE(40));
    const shentsize = header.readUInt16LE(58);
    const shnum = header.readUInt16LE(60);

    const sections = Buffer.alloc(shentsize * shnum);
    fs.readSync(fd, sections, 0, sections.length, shoff);

    let verdefAddr = null;
    let dynamic = null;
    for (let index = 0; index < shnum; index += 1) {
      const base = index * shentsize;
      const type = sections.readUInt32LE(base + 4);
      if (type === SHT_GNU_VERDEF) {
        verdefAddr = sections.readBigUInt64LE(base + 16);
      } else if (type === SHT_DYNAMIC) {
        dynamic = {
          offset: Number(sections.readBigUInt64LE(base + 24)),
          size: Number(sections.readBigUInt64LE(base + 32)),
        };
      }
    }

    if (verdefAddr === null) {
      console.log(`fix-dt-verdef: ${path}: no .gnu.version_d, nothing to do`);
      return;
    }
    if (dynamic === null) {
      throw new Error(`${path}: no SHT_DYNAMIC section`);
    }

    const dyn = Buffer.alloc(dynamic.size);
    fs.readSync(fd, dyn, 0, dyn.length, dynamic.offset);
    for (let cursor = 0; cursor + 16 <= dyn.length; cursor += 16) {
      const tag = dyn.readBigUInt64LE(cursor);
      if (tag === DT_NULL) break;
      if (tag !== DT_VERDEF) continue;

      const current = dyn.readBigUInt64LE(cursor + 8);
      if (current === verdefAddr) {
        console.log(`fix-dt-verdef: ${path}: DT_VERDEF already 0x${verdefAddr.toString(16)}`);
        return;
      }
      const value = Buffer.alloc(8);
      value.writeBigUInt64LE(verdefAddr);
      fs.writeSync(fd, value, 0, 8, dynamic.offset + cursor + 8);
      console.log(
        `fix-dt-verdef: ${path}: DT_VERDEF 0x${current.toString(16)} -> 0x${verdefAddr.toString(16)}`,
      );
      return;
    }

    throw new Error(`${path}: .gnu.version_d present but no DT_VERDEF entry`);
  } finally {
    fs.closeSync(fd);
  }
}

const targets = process.argv.slice(2);
if (targets.length === 0) {
  console.error("usage: fix-dt-verdef.mjs <elf>...");
  process.exit(2);
}
for (const target of targets) repair(target);
