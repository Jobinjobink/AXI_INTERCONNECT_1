#!/usr/bin/env python3
"""Reproducible, dependency-free build driver. Requires Icarus and/or Yosys."""
from pathlib import Path
import argparse, hashlib, json, os, platform, shutil, subprocess, sys, time
from datetime import datetime, timezone
ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
REPORTS = ROOT / 'reports'
DIRECT_BACKEND = False
SUMMARY = {}
SUMMARY_PATH = None

def tool(name, directory):
    suffix = '.exe' if os.name == 'nt' else ''
    if directory:
        base = Path(directory)
        for candidate in (base / (name + suffix), base / 'bin' / (name + suffix)):
            if candidate.is_file():
                return str(candidate.resolve())
    found = shutil.which(name)
    if not found:
        raise RuntimeError(f'{name} not found. Add it to PATH or use --tool-dir.')
    return found

def execute_direct_backend(cmd, log, env):
    """Run the stock preprocessor and compiler separately, checking both exits.

    Some Windows hosts crash in the Icarus driver pipeline after code emission.
    This mode avoids that pipeline; it never accepts a nonzero compiler status.
    The driver still supplies its complete configuration, including -P overrides.
    """
    started=time.monotonic()
    if '-o' not in cmd:
        raise RuntimeError('Direct backend mode requires an explicit -o output')
    output=(ROOT/cmd[cmd.index('-o')+1]).resolve()
    if not output.is_relative_to(BUILD.resolve()):
        raise RuntimeError('Compiler output must stay inside build/')
    prefix=BUILD/log.stem
    preprocessed=prefix.with_suffix('.preprocessed.sv')
    config=prefix.with_suffix('.iconfig')
    backend_config=prefix.with_suffix('.backend.config')
    for stale in (output,preprocessed,config,backend_config):
        stale.unlink(missing_ok=True)
    preprocess_cmd=list(cmd)
    preprocess_cmd.insert(1,'-E')
    preprocess_cmd[preprocess_cmd.index('-o')+1]=str(preprocessed)
    preprocess_env=env.copy()
    preprocess_env['IVERILOG_ICONFIG']=str(config)
    stages=[]
    combined=[]

    def stage(stage_cmd, stage_env, label):
        stage_started=time.monotonic()
        result=subprocess.run(stage_cmd,cwd=ROOT,env=stage_env,text=True,
                              stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
        stage_log=log.with_name(log.stem+'.'+label+'.log')
        stage_log.write_text(result.stdout,encoding='utf-8')
        combined.append(f'[{label}] exit_code={result.returncode}\n'+result.stdout)
        log.write_text('\n'.join(combined),encoding='utf-8')
        print(result.stdout[-5500:],end='')
        stages.append({'command':stage_cmd,'seconds':round(time.monotonic()-stage_started,3),
                       'exit_code':result.returncode,'log':str(stage_log.relative_to(ROOT))})
        if result.returncode:
            raise RuntimeError(f'Direct backend {label} failed ({result.returncode}); see {stage_log.relative_to(ROOT)}')

    stage(preprocess_cmd,preprocess_env,'preprocess')
    if not preprocessed.is_file() or not config.is_file():
        raise RuntimeError('Icarus preprocessor did not emit source and configuration')
    lines=config.read_text(encoding='utf-8').splitlines()
    basedirs=[line.split(':',1)[1] for line in lines if line.startswith('basedir:')]
    if len(basedirs)!=1 or 'generation:2012' not in lines:
        raise RuntimeError('Unexpected Icarus configuration; missing basedir or SystemVerilog 2012 mode')
    basedir=Path(basedirs[0])
    backend=basedir/('ivl.exe' if os.name=='nt' else 'ivl')
    common_config=basedir/'vvp.conf'
    if not backend.is_file() or not common_config.is_file():
        raise RuntimeError(f'Icarus backend or vvp.conf not found under {basedir}')
    lines=[line for line in lines if not line.startswith(('ivlpp:','out:'))]
    lines.append('out:'+str(output))
    backend_config.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    backend_cmd=[str(backend),'-C',str(backend_config),'-C',str(common_config),str(preprocessed)]
    stage(backend_cmd,env,'backend')
    if not output.is_file() or output.stat().st_size==0:
        raise RuntimeError('Icarus backend succeeded without emitting a compiled image')
    return {'command':cmd,'seconds':round(time.monotonic()-started,3),'exit_code':0,
            'direct_backend':True,'stages':stages,'artifact_emitted':str(output.relative_to(ROOT))}

def execute(cmd, log, env):
    if DIRECT_BACKEND and Path(cmd[0]).stem.lower() == 'iverilog':
        return execute_direct_backend(cmd,log,env)
    started=time.monotonic()
    generated = None
    if Path(cmd[0]).stem.lower() == 'iverilog' and '-o' in cmd:
        generated=(ROOT/cmd[cmd.index('-o')+1]).resolve()
        if not generated.is_relative_to(BUILD.resolve()):
            raise RuntimeError('Compiler output must stay inside build/')
        generated.unlink(missing_ok=True)
    result=subprocess.run(cmd,cwd=ROOT,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    log.write_text(result.stdout, encoding='utf-8')
    print(result.stdout[-5500:],end='')
    if result.returncode:
        raise RuntimeError(f'Command failed ({result.returncode}); see {log.relative_to(ROOT)}')
    return {'command': cmd, 'seconds': round(time.monotonic()-started,3), 'exit_code':result.returncode}


def tool_environment(env, directory):
    result=env.copy()
    if directory:
        base=Path(directory).resolve()
        binary=base/'bin' if (base/'bin').is_dir() else base
        result['PATH']=os.pathsep.join((str(binary),str(binary.parent/'lib'),result.get('PATH','')))
    return result

def require_marker(log, marker):
    if marker not in log.read_text(encoding='utf-8'):
        raise RuntimeError(f'Missing {marker!r} in {log.relative_to(ROOT)}')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action',choices=('test','compile','synth','soc','audit','all'))
    ap.add_argument('--tool-dir',help='Tool binaries directory or OSS CAD Suite root')
    ap.add_argument('--yosys-dir',help='Separate Yosys / OSS CAD Suite root for synthesis or SoC checks')
    ap.add_argument('--seed',type=int,action='append',help='Repeatable seed; may be repeated')
    ap.add_argument('--direct-backend',action='store_true',
                    help='Run stock preprocessing and ivl backend separately; require zero exit status from both stages')
    ap.add_argument('--vcd',action='store_true',help='Save waveforms (can be large)')
    args=ap.parse_args()
    global DIRECT_BACKEND
    DIRECT_BACKEND=args.direct_backend
    BUILD.mkdir(exist_ok=True); REPORTS.mkdir(exist_ok=True)
    env=os.environ.copy()
    if args.tool_dir:
        base=Path(args.tool_dir).resolve()
        binary=base/'bin' if (base/'bin').is_dir() else base
        env['PATH']=os.pathsep.join((str(binary),str(binary.parent/'lib'),env.get('PATH','')))
    global SUMMARY, SUMMARY_PATH
    SUMMARY_PATH=REPORTS/f'{args.action}_summary.json'
    source_hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted(ROOT.rglob('*')) if p.is_file()
                   and p.suffix in ('.sv','.v','.f','.py','.ys','.do')
                   and not set(p.relative_to(ROOT).parts).intersection(('build','__pycache__','reports'))}
    summary={'action':args.action, 'status':'RUNNING',
             'started_utc':datetime.now(timezone.utc).isoformat(),
             'python':sys.version, 'platform':platform.platform(),
             'source_sha256':source_hashes, 'runs':[]}
    SUMMARY=summary
    SUMMARY_PATH.write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    if args.action in ('audit','all'):
        summary['runs'].append(execute([sys.executable,'scripts/audit_sources.py','--skip-package'],REPORTS/'source_audit.log',env))
    if args.action in ('compile','test','all'):
        iv=tool('iverilog',args.tool_dir)
        configs=[('default',{}),('wide',{'DATA_WIDTH':64,'ADDR_WIDTH':40,'ID_WIDTH':8}),
                 ('small',{'THREADS':1,'ACCEPT':2,'ISSUE':1,'ID_WIDTH':1})]
        for name, params in configs:
            cmd=[iv,'-g2012','-Wall','-s','axi4_interconnect_4x4','-o',f'build/compile_{name}.vvp','-c','filelist.f']
            cmd += [f'-Paxi4_interconnect_4x4.{k}={v}' for k,v in params.items()]
            summary['runs'].append(execute(cmd,REPORTS/f'compile_{name}.log',env))
    if args.action in ('test','all'):
        iv=tool('iverilog',args.tool_dir); vv=tool('vvp',args.tool_dir)
        test_sources=[str(p.relative_to(ROOT)).replace('\\','/') for p in sorted((ROOT/'tb').glob('*.sv'))]
        cmd=[iv,'-g2012','-Wall','-s','tb_axi4_interconnect','-o','build/regression.vvp','-c','filelist.f']+test_sources
        summary['runs'].append(execute(cmd,REPORTS/'compile_testbench.log',env))
        for seed in args.seed or [1,42,2026]:
            cmd=[vv,'build/regression.vvp',f'+SEED={seed}'] + (['+VCD'] if args.vcd else [])
            log=REPORTS/f'simulation_seed_{seed}.log'
            run=execute(cmd,log,env)
            if 'REGRESSION PASS' not in log.read_text(encoding='utf-8'):
                raise RuntimeError(f'Missing REGRESSION PASS marker in {log.name}')
            run['seed']=seed; summary['runs'].append(run)
    if args.action in ('test','all'):
        # Exercise both non-bypass target response slices. BID is deliberately
        # changed when BVALID is low so a register-boundary tag bug cannot hide.
        for mode in (1,2):
            output=f'build/regression_breg_{mode}.vvp'
            cmd=[iv,'-g2012','-Wall','-s','tb_axi4_interconnect','-o',output,
                 '-c','filelist.f',f'-Ptb_axi4_interconnect.TARGET_B_REG_TYPE={mode}']+test_sources
            summary['runs'].append(execute(cmd,REPORTS/f'compile_breg_{mode}.log',env))
            log=REPORTS/f'simulation_breg_{mode}.log'
            summary['runs'].append(execute([vv,output,'+SEED=42'],log,env))
            require_marker(log,'REGRESSION PASS')
        for top, sources, marker in (
            ('tb_owner_table',['rtl/axi_write_owner_table.sv','tb/tb_owner_table.sv'],'OWNER TABLE PASS'),
            ('tb_owner_checker_negative',['tb/axi4_owner_checker.sv','tb/tb_owner_checker_negative.sv'],'OWNER CHECKER LEGAL PASS')):
            output=f'build/{top}.vvp'
            summary['runs'].append(execute([iv,'-g2012','-s',top,'-o',output]+sources,REPORTS/f'compile_{top}.log',env))
            log=REPORTS/f'{top}.log'
            summary['runs'].append(execute([vv,output,'+CASE=0'],log,env))
            require_marker(log,marker)
        for case,reason in {1:'changed before accepted WLAST',2:'release without accepted WLAST'}.items():
            cmd=[vv,'build/tb_owner_checker_negative.vvp',f'+CASE={case}']
            result=subprocess.run(cmd,cwd=ROOT,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
            (REPORTS/f'owner_negative_{case}.log').write_text(result.stdout,encoding='utf-8')
            if result.returncode==0 or reason not in result.stdout:
                raise RuntimeError(f'Owner checker case {case} did not reject {reason}')
            summary['runs'].append({'command':cmd,'expected_failure':reason,'exit_code':result.returncode})
        cmd=[iv,'-g2012','-s','tb_config','-o','build/config.vvp','-c','filelist.f','tb/tb_config.sv']
        summary['runs'].append(execute(cmd,REPORTS/'compile_config.log',env))
        summary['runs'].append(execute([vv,'build/config.vvp'],REPORTS/'config.log',env))
        require_marker(REPORTS/'config.log','CONFIG PASS')
        # Prove that the checker actually detects representative violations.
        cmd=[iv,'-g2012','-s','tb_checker_negative','-o','build/checker.vvp',
             'tb/axi4_protocol_checker.sv','tb/tb_checker_negative.sv']
        summary['runs'].append(execute(cmd,REPORTS/'compile_checker.log',env))
        summary['runs'].append(execute([vv,'build/checker.vvp','+CASE=0'],REPORTS/'checker_legal.log',env))
        require_marker(REPORTS/'checker_legal.log','CHECKER_POSITIVE_PASS')
        reasons={1:'burst crosses 4KB boundary',2:'WLAST disagrees with AWLEN',
                 3:'AR changed while stalled',4:'B without completed AW/W',
                 5:'missing WLAST at AWLEN boundary'}
        for case, reason in reasons.items():
            cmd=[vv,'build/checker.vvp',f'+CASE={case}']
            result=subprocess.run(cmd,cwd=ROOT,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
            (REPORTS/f'checker_negative_{case}.log').write_text(result.stdout,encoding='utf-8')
            if result.returncode==0 or reason not in result.stdout:
                raise RuntimeError(f'Checker negative case {case} failed to detect expected violation: {reason}')
            summary['runs'].append({'command':cmd,'expected_failure':reason,'exit_code':result.returncode})
            print(f'Checker case {case} detected: {reason}')
    if args.action in ('soc','all'):
        cmd=[sys.executable,'soc_project/scripts/run.py']
        if args.tool_dir: cmd+=['--tool-dir',args.tool_dir]
        if args.yosys_dir: cmd+=['--yosys-dir',args.yosys_dir]
        if args.direct_backend: cmd+=['--direct-backend']
        summary['runs'].append(execute(cmd,REPORTS/'soc_driver.log',env))
        require_marker(REPORTS/'soc_driver.log','SOC CHECKS COMPLETE')
    if args.action in ('synth','all'):
        ys=tool('yosys',args.yosys_dir or args.tool_dir)
        env=tool_environment(env,args.yosys_dir or args.tool_dir)
        summary['runs'].append(execute([ys,'-s','scripts/synth.ys'],REPORTS/'synthesis.log',env))
    summary['status']='PASS'
    summary['finished_utc']=datetime.now(timezone.utc).isoformat()
    (REPORTS/f'{args.action}_summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print(f'{args.action.upper()} CHECKS COMPLETE; direct_backend={DIRECT_BACKEND}; reports in {REPORTS}')

if __name__=='__main__':
    try: main()
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        if SUMMARY_PATH is not None:
            SUMMARY['status']='FAIL'
            SUMMARY['error']=str(exc)
            SUMMARY['finished_utc']=datetime.now(timezone.utc).isoformat()
            SUMMARY_PATH.write_text(json.dumps(SUMMARY,indent=2)+'\n',encoding='utf-8')
        print(f'ERROR: {exc}',file=sys.stderr); sys.exit(1)