#!/usr/bin/env python3
"""Create and verify a deterministic source ZIP; no third-party packages required."""
from pathlib import Path
import argparse, hashlib, json, zipfile

ROOT=Path(__file__).resolve().parents[1]
EXCLUDE={'build','__pycache__','.git'}

def project_files():
    for p in sorted(ROOT.rglob('*')):
        rel=p.relative_to(ROOT)
        if set(rel.parts).intersection(EXCLUDE):
            continue
        if p.is_symlink():
            raise RuntimeError(f'Symlink not allowed in delivery: {rel}')
        if p.is_file() and p.suffix not in ('.pyc','.vcd','.wlf'):
            yield p

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',required=True,help='ZIP path outside the source tree')
    args=ap.parse_args()
    output=Path(args.output).resolve()
    if output.is_relative_to(ROOT):
        raise RuntimeError('Keep the ZIP outside the source tree')
    files=[p for p in project_files() if p.name!='SHA256SUMS']
    sums=''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(ROOT).as_posix()}\n' for p in files)
    (ROOT/'SHA256SUMS').write_bytes(sums.encode('utf-8'))
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for p in project_files():
            info=zipfile.ZipInfo(ROOT.name+'/'+p.relative_to(ROOT).as_posix(),date_time=(2026,10,26,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            info.external_attr=0o100644<<16
            archive.writestr(info,p.read_bytes())
    with zipfile.ZipFile(output) as archive:
        bad=archive.testzip()
        if bad: raise RuntimeError(f'Corrupt ZIP member: {bad}')
        for line in sums.splitlines():
            expected,name=line.split('  ',1)
            actual=hashlib.sha256(archive.read(ROOT.name+'/'+name)).hexdigest()
            if actual!=expected: raise RuntimeError(f'ZIP checksum mismatch: {name}')
        result={'zip':output.name,'files':len(archive.namelist()),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'crc_and_member_hashes':'PASS'}
    output.with_suffix('.zip.sha256').write_text(result['sha256']+'  '+output.name+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2))

if __name__=='__main__': main()
