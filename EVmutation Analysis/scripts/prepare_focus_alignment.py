#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,re
from pathlib import Path
from Bio import AlignIO
AA=set('ACDEFGHIKLMNPQRSTVWY')

def norm_id(x): return x.split()[0].split('/')[0]
def clean(seq): return ''.join(c.upper() if c.upper() in AA else '-' for c in seq)
def write_record(h,i,s):
    h.write(f'>{i}\n')
    for x in range(0,len(s),80): h.write(s[x:x+80]+'\n')

def main():
    p=argparse.ArgumentParser(); p.add_argument('--stockholm',required=True,type=Path); p.add_argument('--output',required=True,type=Path); p.add_argument('--stats',required=True,type=Path); p.add_argument('--target-id',default='BhNIT'); p.add_argument('--minimum-coverage',type=float,default=.70); a=p.parse_args()
    aln=AlignIO.read(str(a.stockholm),'stockholm')
    ti=next((i for i,r in enumerate(aln) if norm_id(r.id)==a.target_id),None)
    if ti is None: raise ValueError(f'Target {a.target_id} not found.')
    traw=str(aln[ti].seq); cols=[i for i,c in enumerate(traw) if c not in '-.']
    target=clean(''.join(traw[i] for i in cols))
    if '-' in target: raise ValueError('Focus sequence contains unsupported residues.')
    order=[ti]+[i for i in range(len(aln)) if i!=ti]; records=[]; stats=[]
    for oi,ai in enumerate(order):
        rec=aln[ai]; centered=clean(''.join(str(rec.seq)[c] for c in cols)); cov=sum(c!='-' for c in centered)/len(centered); is_target=ai==ti; keep=is_target or cov>=a.minimum_coverage
        stats.append({'original_id':rec.id,'normalized_id':norm_id(rec.id),'coverage':cov,'retained':keep,'is_target':is_target})
        if keep:
            ident=a.target_id if is_target else f"homolog_{oi:07d}_{re.sub(r'[^A-Za-z0-9_.-]','_',rec.id)}"
            records.append((ident,centered))
    a.output.parent.mkdir(parents=True,exist_ok=True); a.stats.parent.mkdir(parents=True,exist_ok=True)
    with a.output.open('w') as h:
        for i,s in records: write_record(h,i,s)
    with a.stats.open('w',encoding='utf-8-sig',newline='') as h:
        w=csv.DictWriter(h,fieldnames=stats[0]); w.writeheader(); w.writerows(stats)
    print('Input alignment sequences:',len(aln)); print('Focus sequence length:',len(target)); print('Retained sequences:',len(records)); print('Minimum sequence coverage:',a.minimum_coverage); return 0
if __name__=='__main__': raise SystemExit(main())
