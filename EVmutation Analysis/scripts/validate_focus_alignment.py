#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

def read_fasta(path):
    records=[]; header=None; parts=[]
    for raw in path.read_text().splitlines():
        line=raw.strip()
        if not line: continue
        if line.startswith('>'):
            if header is not None: records.append((header,''.join(parts)))
            header=line[1:].split()[0]; parts=[]
        else: parts.append(line)
    if header is not None: records.append((header,''.join(parts)))
    return records

def main():
    p=argparse.ArgumentParser(); p.add_argument('--alignment',required=True,type=Path); p.add_argument('--target-id',default='BhNIT'); p.add_argument('--expected-length',type=int); a=p.parse_args()
    rec=read_fasta(a.alignment); lengths=sorted({len(s) for _,s in rec}); first,target=rec[0]
    print('Number of sequences:',len(rec)); print('Alignment lengths:',lengths); print('First identifier:',first); print('BhNIT contains gaps:','-' in target)
    errors=[]
    if len(lengths)!=1: errors.append('different alignment lengths')
    if first!=a.target_id: errors.append('target is not first')
    if '-' in target: errors.append('target contains gaps')
    if any(c.islower() for c in target): errors.append('target contains lowercase')
    if a.expected_length and len(target)!=a.expected_length: errors.append(f'expected length {a.expected_length}, found {len(target)}')
    if errors:
        for e in errors: print('ERROR:',e)
        return 2
    print('Focus alignment validation: OK'); return 0
if __name__=='__main__': raise SystemExit(main())
