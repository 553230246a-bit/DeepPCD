#!/usr/bin/env python3
from __future__ import annotations
import argparse, re, sys
from pathlib import Path
AA_CODES=set('ACDEFGHIKLMNPQRSTVWY')
PATTERN=re.compile(r'^([A-Z])(.)(-?\d+[A-Za-z]?)([A-Z]);$')

def main()->int:
    p=argparse.ArgumentParser()
    p.add_argument('mutation_file',type=Path)
    a=p.parse_args()
    if not a.mutation_file.is_file():
        print(f'ERROR: file not found: {a.mutation_file}',file=sys.stderr); return 2
    lines=[x.strip() for x in a.mutation_file.read_text(encoding='ascii').splitlines() if x.strip() and not x.startswith('#')]
    seen=set()
    for i,line in enumerate(lines,1):
        m=PATTERN.fullmatch(line)
        if not m:
            print(f'ERROR: line {i} has invalid FoldX syntax: {line}',file=sys.stderr); return 2
        wt,chain,res,mut=m.groups()
        if wt not in AA_CODES or mut not in AA_CODES or wt==mut or chain.isspace():
            print(f'ERROR: line {i} is invalid: {line}',file=sys.stderr); return 2
        if line in seen:
            print(f'ERROR: duplicate mutation: {line}',file=sys.stderr); return 2
        seen.add(line)
    print(f'Validated {len(lines)} unique single-point mutations.')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
