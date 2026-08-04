#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, re
from pathlib import Path
AA=set('ACDEFGHIKLMNPQRSTVWY')

def read_fasta(path):
    lines=path.read_text(encoding='utf-8').splitlines()
    if not lines or not lines[0].startswith('>'):
        raise ValueError('Invalid single-record FASTA file.')
    identifier=lines[0][1:].split()[0]
    sequence=re.sub(r'\s+','',''.join(lines[1:])).upper()
    invalid=sorted(set(sequence)-AA)
    if not sequence: raise ValueError('Empty sequence.')
    if invalid: raise ValueError(f'Unsupported symbols: {invalid}')
    return identifier,sequence

def main():
    p=argparse.ArgumentParser(); p.add_argument('--fasta',required=True,type=Path); p.add_argument('--mutations',required=True,type=Path); p.add_argument('--target-id',default='BhNIT'); a=p.parse_args()
    identifier,seq=read_fasta(a.fasta)
    with a.mutations.open(encoding='utf-8',newline='') as h: muts=list(csv.DictReader(h,delimiter='\t'))
    errors=[]
    print('Sequence identifier:',identifier); print('Sequence length:',len(seq))
    for r in muts:
        wt,pos,mut=r['wild_type'],int(r['position']),r['mutant']; name=f'{wt}{pos}{mut}'
        observed=seq[pos-1] if 1<=pos<=len(seq) else 'OUT_OF_RANGE'
        status='OK' if observed==wt else 'MISMATCH'
        if status!='OK': errors.append(f'{name}: expected {wt}, observed {observed}')
        print(f'{name:8s} position={pos:<4d} expected={wt} observed={observed} status={status}')
    if identifier!=a.target_id: errors.append(f'Expected identifier {a.target_id}, found {identifier}')
    if len(muts)!=22: errors.append(f'Expected 22 mutations, found {len(muts)}')
    if errors:
        for e in errors: print('ERROR:',e)
        return 2
    print('\nAll 22 mutation sites were validated successfully.'); return 0
if __name__=='__main__': raise SystemExit(main())
