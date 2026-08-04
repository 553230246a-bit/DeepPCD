#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,json,re,sys
from pathlib import Path
from evcouplings.couplings.model import CouplingsModel
PATTERN=re.compile(r'^([ACDEFGHIKLMNPQRSTVWY])([1-9][0-9]*)([ACDEFGHIKLMNPQRSTVWY])$')

def read_mutations(path):
    with path.open(encoding='utf-8-sig',newline='') as h: reader=csv.DictReader(h); rows=list(reader)
    out=[]; seen=set()
    for n,row in enumerate(rows,2):
        name=str(row['mutant']).strip().upper(); m=PATTERN.fullmatch(name)
        if not m: raise ValueError(f'Invalid mutation on line {n}: {name}')
        wt,pos,mut=m.groups()
        if name in seen: raise ValueError(f'Duplicate mutation: {name}')
        seen.add(name); out.append((wt,int(pos),mut,name))
    if len(out)!=22: raise ValueError(f'Expected 22 mutations, found {len(out)}')
    return out

def native(v):
    try:return v.item()
    except AttributeError:return v

def main():
    p=argparse.ArgumentParser(); p.add_argument('--model',required=True,type=Path); p.add_argument('--mutations',required=True,type=Path); p.add_argument('--output',required=True,type=Path); p.add_argument('--metadata',required=True,type=Path); p.add_argument('--precision',choices=['float32','float64'],default='float32'); a=p.parse_args()
    muts=read_mutations(a.mutations)
    with a.model.open('rb') as h: model=CouplingsModel(h,precision=a.precision,file_format='plmc_v2')
    if not model.has_target_seq: raise ValueError('Model has no focus sequence; rebuild with plmc -f.')
    independent=model.to_independent_model(); target={int(i):str(r) for i,r in zip(model.index_list,model.target_seq)}; errors=[]
    for wt,pos,mut,name in muts:
        obs=target.get(pos); status='OK' if obs==wt else ('NOT_MODELED' if obs is None else 'MISMATCH')
        if status!='OK': errors.append(f'{name}: expected {wt}, observed {obs}')
        print(f'{name:8s} position={pos:<4d} expected={wt} observed={obs} status={status}')
    if errors:
        for e in errors: print('ERROR:',e,file=sys.stderr)
        return 2
    print('\nAll 22 mutation sites were validated successfully.\n')
    rows=[]
    for order,(wt,pos,mut,name) in enumerate(muts,1):
        sub=[(pos,wt,mut)]; epi=model.delta_hamiltonian(sub,verify_mutants=True); ind=independent.delta_hamiltonian(sub,verify_mutants=True)
        row={'mutant':name,'position':pos,'wild_type':wt,'substitution':mut,'deltaE_epistatic_full':float(epi[0]),'deltaE_epistatic_couplings':float(epi[1]),'deltaE_epistatic_fields':float(epi[2]),'deltaE_independent':float(ind[0]),'input_order':order}; rows.append(row)
        print(f"[{order:02d}/22] {name}: epistatic ΔE={row['deltaE_epistatic_full']:.6f}; independent ΔE={row['deltaE_independent']:.6f}")
    a.output.parent.mkdir(parents=True,exist_ok=True)
    with a.output.open('w',encoding='utf-8-sig',newline='') as h: w=csv.DictWriter(h,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    meta={'model_file':str(a.model.resolve()),'model_precision':a.precision,'model_length':int(model.L),'N_valid':native(model.N_valid),'N_invalid':native(model.N_invalid),'N_eff':native(model.N_eff),'theta':native(model.theta),'lambda_h':native(model.lambda_h),'lambda_J':native(model.lambda_J),'lambda_group':native(model.lambda_group),'plmc_iterations':native(model.num_iter),'number_of_mutations':22,'units':'dimensionless evolutionary statistical-energy units; not kcal/mol and not thermodynamic ΔΔG','score_definition':'mutant Hamiltonian minus target-sequence Hamiltonian as returned by CouplingsModel.delta_hamiltonian'}
    a.metadata.write_text(json.dumps(meta,indent=2),encoding='utf-8')
    print('\nEVmutation calculation completed successfully.'); print('Result CSV:',a.output); print('Metadata JSON:',a.metadata); return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as exc: print(f'ERROR: {exc}',file=sys.stderr); raise SystemExit(2)
