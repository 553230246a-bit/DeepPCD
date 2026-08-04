#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,re,statistics,sys
from pathlib import Path

def split_line(line:str)->list[str]:
    line=line.rstrip('\r\n')
    return [x.strip() for x in (line.split('\t') if '\t' in line else re.split(r'\s{2,}',line.strip()))]

def norm(s:str)->str:
    return re.sub(r'\s+',' ',s.strip().lower())

def read_mutations(path:Path)->list[str]:
    vals=[x.strip().rstrip(';') for x in path.read_text(encoding='ascii').splitlines() if x.strip() and not x.startswith('#')]
    if not vals: raise ValueError('No mutations found.')
    return vals

def parse_dif(path:Path):
    lines=path.read_text(encoding='utf-8',errors='replace').splitlines()
    header=None; idx=None
    for i,line in enumerate(lines):
        f=split_line(line); n=[norm(x) for x in f]
        if 'total energy' in n and any(x.startswith('pdb') for x in n):
            header=f; idx=i; break
    if header is None: raise ValueError('Could not locate FoldX table header.')
    rows=[]
    for line in lines[idx+1:]:
        if not line.strip() or line.lstrip().startswith('#'): continue
        f=split_line(line)
        if len(f)>=len(header): rows.append(dict(zip(header,f[:len(header)])))
    if not rows: raise ValueError('No FoldX data rows found.')
    return header,rows

def classify(v:float,b:float)->str:
    if v<=-b:return 'predicted_stabilizing'
    if v>=b:return 'predicted_destabilizing'
    return 'near_neutral_uncertain'

def write_csv(path:Path,fields,rows):
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('w',encoding='utf-8-sig',newline='') as h:
        w=csv.DictWriter(h,fieldnames=fields); w.writeheader(); w.writerows(rows)

def main()->int:
    p=argparse.ArgumentParser()
    p.add_argument('--dif',required=True,type=Path)
    p.add_argument('--mutations',required=True,type=Path)
    p.add_argument('--runs',required=True,type=int)
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--long-output',required=True,type=Path)
    p.add_argument('--neutral-band',type=float,default=0.5)
    a=p.parse_args()
    try:
        muts=read_mutations(a.mutations); header,rows=parse_dif(a.dif)
        pdb_col=next(x for x in header if norm(x).startswith('pdb'))
        e_col=next(x for x in header if norm(x)=='total energy')
        vals=[(r[pdb_col],float(r[e_col])) for r in rows]
        expected=len(muts)*a.runs
        if len(vals)!=expected: raise ValueError(f'Expected {expected} rows, found {len(vals)}.')
        grouped={m:[] for m in muts}; long=[]
        for i,(pdb,ddg) in enumerate(vals):
            mi=i//a.runs; ri=i%a.runs+1; m=muts[mi]; grouped[m].append(ddg)
            long.append({'mutation':m,'run':ri,'pdb_record':pdb,'ddg_kcal_mol':f'{ddg:.6f}'})
        summary=[]
        for m in muts:
            x=grouped[m]; mean=statistics.fmean(x); sd=statistics.stdev(x) if len(x)>1 else 0.0
            summary.append({'mutation':m,'n_runs':len(x),'mean_ddg_kcal_mol':f'{mean:.6f}','sd_ddg_kcal_mol':f'{sd:.6f}','min_ddg_kcal_mol':f'{min(x):.6f}','max_ddg_kcal_mol':f'{max(x):.6f}','exploratory_classification':classify(mean,a.neutral_band)})
        write_csv(a.long_output,['mutation','run','pdb_record','ddg_kcal_mol'],long)
        write_csv(a.output,['mutation','n_runs','mean_ddg_kcal_mol','sd_ddg_kcal_mol','min_ddg_kcal_mol','max_ddg_kcal_mol','exploratory_classification'],summary)
        print(f'Parsed {len(muts)} mutations with {a.runs} runs each.')
        return 0
    except Exception as e:
        print(f'ERROR: {e}',file=sys.stderr); return 2

if __name__=='__main__':
    raise SystemExit(main())
