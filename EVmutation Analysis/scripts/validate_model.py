#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv
from pathlib import Path
from evcouplings.couplings.model import CouplingsModel

def main():
    p=argparse.ArgumentParser(); p.add_argument('--model',required=True,type=Path); p.add_argument('--mutations',required=True,type=Path); p.add_argument('--precision',choices=['float32','float64'],default='float32'); a=p.parse_args()
    with a.model.open('rb') as h: model=CouplingsModel(h,precision=a.precision,file_format='plmc_v2')
    with a.mutations.open(encoding='utf-8',newline='') as h: muts=list(csv.DictReader(h,delimiter='\t'))
    target={int(i):str(r) for i,r in zip(model.index_list,model.target_seq)}
    print('Model loaded: OK'); print('Modeled positions:',model.L); print('Valid sequences:',model.N_valid); print('Effective sequence count:',model.N_eff); print('Theta:',model.theta); print('plmc iterations:',model.num_iter)
    errors=[]
    for row in muts:
        wt,pos,mut=row['wild_type'],int(row['position']),row['mutant']; name=f'{wt}{pos}{mut}'; observed=target.get(pos)
        status='OK' if observed==wt else ('NOT_MODELED' if observed is None else 'MISMATCH')
        if status!='OK': errors.append(name)
        print(f'{name:8s} expected={wt} observed={observed} status={status}')
    if errors: print('ERROR: failed mutations:',', '.join(errors)); return 2
    print('\nAll 22 mutation positions are represented correctly.'); return 0
if __name__=='__main__': raise SystemExit(main())
