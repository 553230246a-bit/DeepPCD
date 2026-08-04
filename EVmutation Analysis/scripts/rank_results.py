#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv
from pathlib import Path

def main():
    p=argparse.ArgumentParser(); p.add_argument('--input',required=True,type=Path); p.add_argument('--output',required=True,type=Path); a=p.parse_args()
    with a.input.open(encoding='utf-8-sig',newline='') as h: rows=list(csv.DictReader(h))
    rows.sort(key=lambda r:float(r['deltaE_epistatic_full']),reverse=True); out=[]
    for rank,row in enumerate(rows,1):
        note='top_ranked_candidate' if rank<=4 else 'secondary_candidate' if rank<=6 else 'exploratory_candidate' if rank<=10 else 'lower_priority_by_EVmutation'
        out.append({'EVmutation_rank':rank,**row,'epistatic_vs_independent_shift':float(row['deltaE_epistatic_full'])-float(row['deltaE_independent']),'screening_note':note})
    a.output.parent.mkdir(parents=True,exist_ok=True)
    with a.output.open('w',encoding='utf-8-sig',newline='') as h: w=csv.DictWriter(h,fieldnames=list(out[0])); w.writeheader(); w.writerows(out)
    for r in out: print(f"{int(r['EVmutation_rank']):2d} {r['mutant']:8s} {float(r['deltaE_epistatic_full']): .6f} {r['screening_note']}")
    print('\nRanked output:',a.output); return 0
if __name__=='__main__': raise SystemExit(main())
