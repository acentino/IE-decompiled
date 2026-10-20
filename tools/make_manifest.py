#!/usr/bin/env python3
"""Read a user-supplied French Inazuma Eleven .nds (or ZIP of one) and emit ONLY metadata.
This is a format analysis utility; it does not emulate or execute any guest code.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct
import zipfile


def u16(b, p):
    return struct.unpack_from('<H', b, p)[0]


def u32(b, p):
    return struct.unpack_from('<I', b, p)[0]


def load_input(path):
    if path.suffix.lower() == '.zip':
        with zipfile.ZipFile(path) as z:
            candidates = [i for i in z.infolist() if not i.is_dir() and i.filename.lower().endswith('.nds')]
            if len(candidates) != 1:
                raise ValueError('ZIP must contain exactly one .nds ROM')
            if candidates[0].file_size > 512 * 1024 * 1024:
                raise ValueError('NDS exceeds size limit')
            return z.read(candidates[0])
    if path.stat().st_size > 512 * 1024 * 1024:
        raise ValueError('NDS exceeds size limit')
    return path.read_bytes()


def manifest(b):
    if len(b) < 0x200 or b[12:16] != b'YEEF':
        raise ValueError('Expected French Inazuma Eleven 1 game code YEEF')
    def table(offset_field, size_field):
        p = u32(b, offset_field)
        n = u32(b, size_field)
        if p + n > len(b):
            raise ValueError('Bad table range')
        return b[p:p+n]

    fnt = table(0x40, 0x44)
    fat = table(0x48, 0x4c)
    ovtab = table(0x50, 0x54)
    if len(fat) % 8 or len(ovtab) % 32:
        raise ValueError('Invalid FAT or overlay size')
    file_count = len(fat) // 8
    files = []
    for file_id in range(file_count):
        start,end = struct.unpack_from('<II', fat, file_id * 8)
        if end < start or end > len(b):
            raise ValueError(f'Invalid FAT entry {file_id}')
        signature = b[start:min(end,start+4)]
        files.append({'id':file_id,'path':None,'rom_offset':start,'size':end-start,
                      'signature_hex':signature.hex(),
                      'lz10_header':len(signature)==4 and signature[0] == 0x10 and int.from_bytes(signature[1:4],'little')>0})

    dir_count=u16(fnt,6)
    if dir_count*8>len(fnt):
        raise ValueError('Bad FNT directory count')
    visited=set()
    def walk(dirid,prefix,depth=0):
        idx=dirid-0xf000
        if idx<0 or idx>=dir_count or dirid in visited or depth>32:
            raise ValueError('Invalid FNT tree')
        visited.add(dirid)
        pos=u32(fnt,idx*8)
        fileid=u16(fnt,idx*8+4)
        while pos<len(fnt):
            tag=fnt[pos];pos+=1
            if tag==0:break
            namelen=tag&127
            if namelen>len(fnt)-pos:raise ValueError('FNT name overrun')
            name=fnt[pos:pos+namelen].decode('shift_jis','replace')
            pos+=namelen
            if '/' in name or '\\' in name or name in ('.','..'):
                raise ValueError('Unsafe FNT filename')
            if tag&128:
                if pos+2>len(fnt):raise ValueError('Truncated FNT directory ID')
                child=u16(fnt,pos);pos+=2
                walk(child,prefix+name+'/',depth+1)
            else:
                if fileid>=len(files):raise ValueError('FNT file ID outside FAT')
                files[fileid]['path']=prefix+name
                fileid+=1
        else:raise ValueError('Unterminated FNT directory')
    walk(0xf000,'')
    overlays=[]
    for i in range(len(ovtab)//32):
        overlay_id,address,size,bss,init_start,init_end,file_id,flags=struct.unpack_from('<8I',ovtab,i*32)
        if file_id>=file_count:raise ValueError('Overlay file ID invalid')
        overlays.append({'id':overlay_id,'ram_address':f'0x{address:08X}', 'ram_size':size,
                         'bss_size':bss,'static_init_start':f'0x{init_start:08X}',
                         'static_init_end':f'0x{init_end:08X}', 'file_id':file_id,
                         'compressed':bool(flags&0x01000000),'packed_size':files[file_id]['size'],
                         'flags_hex':f'0x{flags:08X}'})
    def binary(off):
        src,entry,load,size=struct.unpack_from('<4I',b,off)
        return {'rom_offset':f'0x{src:X}','ram_load':f'0x{load:08X}',
                'entry_point':f'0x{entry:08X}', 'size':size}
    ext_count=collections.Counter(PurePosixPath(f['path']).suffix.lower() or '(none)'
                                  for f in files if f['path'] is not None)
    return {
      'game':{'title':b[:12].rstrip(b'\0').decode('ascii','replace'),
              'game_code':b[12:16].decode('ascii'),
              'maker_code':b[16:18].decode('ascii','replace'),
              'rom_bytes':len(b),
              'sha1':hashlib.sha1(b).hexdigest(),
              'sha256':hashlib.sha256(b).hexdigest()},
      'cpu':{'arm9':binary(0x20),'arm7':binary(0x30)},
      'filesystem':{'file_ids':file_count,'named_files':sum(f['path'] is not None for f in files),
                    'directories':len(visited),'lz10_header_count':sum(f['lz10_header'] for f in files if f['path']),
                    'extensions':dict(sorted(ext_count.items())), 'files':files},
      'arm9_overlays':overlays,
      'arm7_overlay_count':u32(b,0x5c)//32,
    }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input',type=Path,help='.nds or ZIP containing one .nds')
    parser.add_argument('--output',type=Path,default=Path('analysis/manifest.json'))
    args=parser.parse_args()
    meta=manifest(load_input(args.input))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(meta,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(f"Wrote {args.output}: {meta['filesystem']['file_ids']} file IDs, "
          f"{len(meta['arm9_overlays'])} ARM9 overlays, SHA1 {meta['game']['sha1']}")

if __name__=='__main__':main()
