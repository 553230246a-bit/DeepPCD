from pathlib import Path
import csv, subprocess, sys

def test_parser(tmp_path: Path):
    mutation_file = tmp_path / 'individual_list.txt'
    mutation_file.write_text('WA59A;\nVA94A;\n', encoding='ascii')
    dif_file = tmp_path / 'Dif_test.fxout'
    dif_file.write_text(
        'Pdb\tTotal Energy\tBackbone Hbond\n'
        'm1_r1.pdb\t-1.0\t0.0\n'
        'm1_r2.pdb\t-0.8\t0.0\n'
        'm1_r3.pdb\t-0.9\t0.0\n'
        'm2_r1.pdb\t0.7\t0.0\n'
        'm2_r2.pdb\t0.9\t0.0\n'
        'm2_r3.pdb\t0.8\t0.0\n', encoding='utf-8')
    summary = tmp_path / 'summary.csv'
    long_output = tmp_path / 'long.csv'
    script = Path(__file__).resolve().parents[1] / 'scripts' / 'parse_foldx_results.py'
    completed = subprocess.run([
        sys.executable,str(script),'--dif',str(dif_file),'--mutations',str(mutation_file),
        '--runs','3','--output',str(summary),'--long-output',str(long_output)
    ],capture_output=True,text=True)
    assert completed.returncode == 0, completed.stderr
    with summary.open(encoding='utf-8-sig',newline='') as handle:
        rows=list(csv.DictReader(handle))
    assert rows[0]['mean_ddg_kcal_mol']=='-0.900000'
    assert rows[1]['mean_ddg_kcal_mol']=='0.800000'
