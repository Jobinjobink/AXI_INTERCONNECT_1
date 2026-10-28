#!/usr/bin/env python3
"""Offline source-integrity and conservative module-closure audit (Python 3.9+).

Run from any directory. HDL scanning is intentionally NOT a parser/elaborator;
use the compile, simulation and synthesis targets for authoritative tool checks.
Optional --upstream-dir checks pinned upstream hashes and replays local patches.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_SHA256 = '531a405ab48a729d661f2c56c76cceb82c62b7eab5471c3d8243b291ed0e89b0'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def clean(text):
    # Preserve newlines for conservative line-anchored declaration scanning.
    return re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"',
                  lambda m: '\n' * m.group().count('\n'), text, flags=re.S)


def safe_path(root, name):
    p = (root / name).resolve()
    if not p.is_relative_to(root.resolve()):
        raise ValueError('Path escapes project: ' + name)
    return p


def read_filelist(path, root, seen=None):
    seen = set() if seen is None else seen
    path = path.resolve()
    if path in seen:
        raise ValueError('Recursive filelist: ' + str(path))
    seen.add(path)
    result = []
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        line = line.split('//', 1)[0].split('#', 1)[0].strip()
        if not line or line.startswith(('+incdir+', '+define+')):
            continue
        if line.startswith(('-f ', '-F ', '-c ')):
            result += read_filelist(safe_path(root, line[3:].strip()), root, seen)
        elif line.startswith(('-', '+')):
            raise ValueError('Unsupported filelist directive: ' + line)
        else:
            p = safe_path(root, line)
            if not p.is_file():
                raise ValueError('Missing filelist source: ' + line)
            result.append(p)
    seen.remove(path)
    if len(result) != len(set(result)):
        raise ValueError('Duplicate source entries in ' + str(path))
    return result


def module_inventory(paths):
    modules = {}
    for p in paths:
        text = clean(p.read_text(encoding='utf-8-sig'))
        for m in re.finditer(r'\bmodule\s+(\w+)\b(.*?)\bendmodule\b', text, re.S):
            name, body = m.group(1), m.group(2)
            if name in modules:
                raise ValueError('Duplicate module definition: ' + name)
            instances = set()
            # All shipped RTL uses ordinary named, line-anchored instantiations.
            # Balanced parameter parentheses avoid assuming one-line parameters.
            pattern = r'(?m)^\s*(\w+)\s*(?=#\s*\(|\s+\w+\s*(?:\[[^\]]*\]\s*)?\()'
            for inst in re.finditer(pattern, body):
                kind = inst.group(1)
                tail = body[inst.end():].lstrip()
                if tail.startswith('#'):
                    tail = tail[1:].lstrip()
                    depth, end = 0, None
                    for i, ch in enumerate(tail):
                        if ch == '(':
                            depth += 1
                        elif ch == ')':
                            depth -= 1
                            if depth == 0:
                                end = i + 1
                                break
                    if end is None:
                        continue
                    tail = tail[end:].lstrip()
                if not re.match(r'\w+\s*(?:\[[^\]]*\]\s*)?\(', tail):
                    continue
                if kind not in {'if', 'else', 'for', 'while', 'case', 'casez',
                                'casex', 'function', 'task', 'input', 'output',
                                'inout', 'wire', 'reg', 'logic', 'assign',
                                'always', 'always_ff', 'always_comb', 'initial',
                                'module', 'generate', 'begin', 'end', 'assert',
                                'property', 'return', 'automatic', 'integer'}:
                    instances.add(kind)
            modules[name] = {'file': p, 'instances': sorted(instances)}
    missing = sorted({dep for value in modules.values() for dep in value['instances']
                      if dep not in modules})
    if missing:
        raise ValueError('Unresolved module candidates: ' + ', '.join(missing))
    return modules


def apply_patch_text(sources, patch):
    """Strict unified-diff replay; no fuzzy context matching or shell commands."""
    lines = patch.splitlines(keepends=True)
    result, i = {}, 0
    while i < len(lines):
        if not lines[i].startswith('--- a/'):
            raise ValueError('Expected --- a/ at patch line ' + str(i + 1))
        oldname = lines[i][6:].strip()
        i += 1
        if i >= len(lines) or not lines[i].startswith('+++ b/'):
            raise ValueError('Missing +++ b/ patch header')
        newname = lines[i][6:].strip()
        if oldname != newname:
            raise ValueError('Renames are not supported by this vendor patch verifier')
        source = sources[oldname].splitlines(keepends=True)
        output, cursor = [], 0
        i += 1
        while i < len(lines) and not lines[i].startswith('--- a/'):
            hunk = re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', lines[i])
            if not hunk:
                raise ValueError('Invalid hunk header at patch line ' + str(i + 1))
            oldstart = int(hunk.group(1)) - 1
            oldcount = int(hunk.group(2) or 1)
            newcount = int(hunk.group(4) or 1)
            if oldstart < cursor:
                raise ValueError('Overlapping patch hunks')
            output += source[cursor:oldstart]
            cursor = oldstart
            i += 1
            oldused = newused = 0
            while i < len(lines) and not lines[i].startswith(('@@ ', '--- a/')):
                line = lines[i]
                if not line or line[0] not in ' +-':
                    raise ValueError('Invalid patch line ' + str(i + 1))
                op, payload = line[0], line[1:]
                if op in ' -':
                    if cursor >= len(source) or source[cursor] != payload:
                        raise ValueError('Patch context mismatch: ' + oldname + ':' + str(cursor + 1))
                    cursor += 1
                    oldused += 1
                if op in ' +':
                    output.append(payload)
                    newused += 1
                i += 1
            if (oldused, newused) != (oldcount, newcount):
                raise ValueError('Hunk line counts disagree: ' + oldname)
        output += source[cursor:]
        result[newname] = ''.join(output)
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', type=Path, default=ROOT)
    ap.add_argument('--original-zip', type=Path)
    ap.add_argument('--upstream-dir', type=Path)
    ap.add_argument('--skip-package', action='store_true',
                    help='Skip SHA256SUMS while editing; vendor hashes are still checked')
    ap.add_argument('--report', type=Path, help='Optional JSON report; omit for read-only audit')
    args = ap.parse_args()
    root = args.root.resolve()
    report = {'status': 'PASS', 'scope': 'source integrity and conservative module scan',
              'errors': [], 'filelists': {}, 'vendor_files': []}
    try:
        for path in sorted(root.rglob('*.f')):
            if any(part in ('build', 'archive', '__pycache__') for part in path.relative_to(root).parts):
                continue
            sources = read_filelist(path, root)
            modules = module_inventory(sources)
            package_defs = set()
            package_refs = set()
            includes_checked = []
            for source in sources:
                source_text = source.read_text(encoding='utf-8-sig')
                hdl_text = clean(source_text)
                package_defs.update(re.findall(r'\bpackage\s+(\w+)\s*;', hdl_text))
                package_refs.update(re.findall(r'\b(\w+)::', hdl_text))
                for include in re.findall(r'^\s*`include\s+"([^"]+)"', source_text, re.M):
                    candidates = (source.parent / include, root / include)
                    if not any(candidate.is_file() and candidate.resolve().is_relative_to(root)
                               for candidate in candidates):
                        raise ValueError('Missing include: ' + include + ' from ' + str(source))
                    includes_checked.append(include)
            if package_refs - package_defs:
                raise ValueError('Unresolved package candidates: ' + ', '.join(sorted(package_refs - package_defs)))
            report['filelists'][path.relative_to(root).as_posix()] = {
                'packages': sorted(package_defs), 'includes_checked': sorted(set(includes_checked)),
                'source_count': len(sources), 'module_count': len(modules),
                'modules': {name: {'file': value['file'].relative_to(root).as_posix(),
                                   'instantiates': value['instances']}
                            for name, value in sorted(modules.items())}}
        manifest = json.loads((root / 'VENDOR_MANIFEST.json').read_text(encoding='utf-8-sig'))
        upstream_sources = {}
        for entry in manifest['files']:
            path = safe_path(root, entry['path'])
            digest = sha(path.read_bytes())
            if digest != entry['sha256']:
                raise ValueError('Vendor packaged hash mismatch: ' + entry['path'])
            status = {'path': entry['path'], 'sha256': digest, 'packaged_hash': 'PASS'}
            if args.upstream_dir:
                upstream = safe_path(args.upstream_dir, entry['upstream_path'])
                if sha(upstream.read_bytes()) != entry['upstream_sha256']:
                    raise ValueError('Pinned upstream hash mismatch: ' + entry['upstream_path'])
                upstream_sources[entry['path']] = upstream.read_text(encoding='utf-8')
                status['upstream_hash'] = 'PASS'
            report['vendor_files'].append(status)
        if args.upstream_dir:
            patch = (root / 'docs/vendor_fixes.patch').read_text(encoding='utf-8')
            reconstructed = apply_patch_text(upstream_sources, patch)
            for entry in manifest['files']:
                expected = reconstructed.get(entry['path'], upstream_sources[entry['path']])
                if expected != (root / entry['path']).read_text(encoding='utf-8-sig'):
                    raise ValueError('Patch does not reproduce vendor file: ' + entry['path'])
            report['vendor_patch_replay'] = 'PASS'
        if args.original_zip:
            archive = args.original_zip.read_bytes()
            digest = sha(archive)
            if digest != ORIGINAL_SHA256:
                raise ValueError('Original ZIP differs from the audited upload')
            with zipfile.ZipFile(args.original_zip) as z:
                sums_name = next(n for n in z.namelist() if n.endswith('/SHA256SUMS'))
                prefix = sums_name[:-len('SHA256SUMS')]
                checked = 0
                for line in z.read(sums_name).decode().splitlines():
                    expected, name = line.split(None, 1)
                    if sha(z.read(prefix + name.lstrip('* '))) != expected:
                        raise ValueError('Original ZIP manifest mismatch: ' + name)
                    checked += 1
            report['original_zip'] = {'sha256': digest, 'manifest_entries_checked': checked,
                                      'status': 'PASS'}
        if not args.skip_package:
            checked = 0
            for line in (root / 'SHA256SUMS').read_text(encoding='utf-8').splitlines():
                expected, name = line.split(None, 1)
                path = safe_path(root, name.lstrip('* '))
                if sha(path.read_bytes()) != expected:
                    raise ValueError('Package hash mismatch: ' + name)
                checked += 1
            report['package_hashes_checked'] = checked
    except (OSError, ValueError, KeyError, StopIteration, zipfile.BadZipFile) as exc:
        report['status'] = 'FAIL'
        report['errors'].append(str(exc))
    output = json.dumps(report, indent=2) + '\n'
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output, encoding='utf-8')
    print(output, end='')
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
