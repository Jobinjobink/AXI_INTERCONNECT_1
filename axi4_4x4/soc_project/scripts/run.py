#!/usr/bin/env python3
"""Compile and simulate the Mini-SoC integration; synthesize when --yosys-dir is given."""
import sys, os, json, argparse, hashlib, subprocess
from datetime import datetime, timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
import run as runner
SUMMARY={}
SUMMARY_PATH=ROOT/'reports/soc_detail_summary.json'

def main():
    global SUMMARY
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--tool-dir')
    ap.add_argument('--yosys-dir',help='Yosys + slang root; also runs generic synthesis of the legacy-integrated top')
    ap.add_argument('--direct-backend',action='store_true')
    ap.add_argument('--compile-only',action='store_true')
    a=ap.parse_args()
    runner.DIRECT_BACKEND=a.direct_backend
    runner.BUILD.mkdir(exist_ok=True); runner.REPORTS.mkdir(exist_ok=True)
    sources=[p for p in (ROOT/'soc_project').rglob('*') if p.is_file()]
    sources+=[ROOT/p for p in (ROOT/'filelist.f').read_text().splitlines() if p.strip()]
    sources+=[ROOT/'tb/axi4_test_slave.sv']
    SUMMARY={'status':'RUNNING','started_utc':datetime.now(timezone.utc).isoformat(),
             'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted(set(sources))},'runs':[],
             'simulation':'NOT_RUN' if a.compile_only else 'PENDING',
             'synthesis':'PENDING' if a.yosys_dir else 'NOT_RUN: --yosys-dir not supplied'}
    SUMMARY_PATH.write_text(json.dumps(SUMMARY,indent=2)+'\n')
    env=runner.tool_environment(os.environ.copy(),a.tool_dir)
    iv=runner.tool('iverilog',a.tool_dir)
    tops=['soc_axi4_subsystem','soc_axi4_legacy_subsystem']
    if not a.compile_only: tops+=['tb_soc_axi4_subsystem','tb_legacy_id_adapter']
    for top in tops:
        cmd=[iv,'-g2012','-Wall','-s',top,'-o','build/'+top+'.vvp','-c','soc_project/filelist.f']
        if top.startswith('tb_'): cmd+=['soc_project/tb/'+top+'.sv','tb/axi4_test_slave.sv']
        SUMMARY['runs'].append(runner.execute(cmd,runner.REPORTS/('soc_compile_'+top+'.log'),env))
        if top.startswith('tb_'):
            vv=runner.tool('vvp',a.tool_dir)
            log=runner.REPORTS/(top+'.log')
            SUMMARY['runs'].append(runner.execute([vv,'build/'+top+'.vvp'],log,env))
            runner.require_marker(log,'SOC TEST PASS')
    if not a.compile_only: SUMMARY['simulation']='PASS'
    if a.yosys_dir:
        ys=runner.tool('yosys',a.yosys_dir)
        env=runner.tool_environment(env,a.yosys_dir)
        netlist=ROOT/'build/soc_axi4_legacy_subsystem.json'
        netlist.unlink(missing_ok=True)
        SUMMARY['runs'].append(runner.execute([ys,'-s','soc_project/scripts/synth.ys'],
                                              runner.REPORTS/'soc_synthesis.log',env))
        if not netlist.is_file() or not netlist.stat().st_size:
            raise RuntimeError('Synthesis did not generate the expected netlist')
        SUMMARY['synthesis']='PASS'
    SUMMARY['status']='PASS'
    SUMMARY['finished_utc']=datetime.now(timezone.utc).isoformat()
    SUMMARY_PATH.write_text(json.dumps(SUMMARY,indent=2)+'\n')
    print('SOC CHECKS COMPLETE')

if __name__=='__main__':
    try: main()
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        SUMMARY['status']='FAIL'; SUMMARY['error']=str(exc)
        SUMMARY['finished_utc']=datetime.now(timezone.utc).isoformat()
        SUMMARY_PATH.parent.mkdir(exist_ok=True)
        SUMMARY_PATH.write_text(json.dumps(SUMMARY,indent=2)+'\n')
        print('ERROR: '+str(exc),file=sys.stderr)
        sys.exit(1)
