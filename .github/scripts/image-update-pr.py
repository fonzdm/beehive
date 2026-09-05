"""Describe the image changes proposed by Flux using only the Python standard library."""
import json
import os
from pathlib import Path
import re
import subprocess


def git(*args):
    return subprocess.check_output(['git', *args], text=True)


def images(content):
    result = {}
    for line in content.splitlines():
        match = re.search(r'^\s*\w+:\s*(.*?)\s+#\s*(\{.*\})\s*$', line)
        if not match:
            continue
        try:
            marker = json.loads(match[2]).get('$imagepolicy', '')
        except json.JSONDecodeError:
            continue
        if marker.count(':') != 2:
            continue
        namespace, policy, field = marker.split(':')
        result.setdefault(f'{namespace}:{policy}', {})[field] = match[1].strip('\"\'')
    return result


def cell(value):
    return str(value).replace('|', '&#124;').replace('`', '&#96;').replace('\n', ' ')


def main():
    base = git('merge-base', 'origin/main', 'HEAD').strip()
    files = git('diff', '--name-only', '--diff-filter=AM', base, 'HEAD', '--', 'kubernetes').splitlines()
    rows = []
    names = set()
    for filename in files:
        old = git('show', f'{base}:{filename}') if git('ls-tree', base, '--', filename).strip() else ''
        before, after = images(old), images(git('show', f'HEAD:{filename}'))
        for policy, current in after.items():
            previous = before.get(policy, {})
            if previous == current:
                continue
            name = current.get('name', policy)
            names.add(name.rsplit('/', 1)[-1])
            changes = []
            for field in ('name', 'tag', 'digest'):
                if previous.get(field) != current.get(field):
                    changes.append(f"{field}: `{cell(previous.get(field, '(unset)'))}` → `{cell(current.get(field, '(unset)'))}`")
            rows.append(f"| `{cell(name)}` | {'<br>'.join(changes)} | `{cell(filename)}` |")
    title = 'chore(images): update ' + (', '.join(sorted(names)) if names else 'container images')
    if len(title) > 120:
        title = f'chore(images): update {len(names)} container images'
    body = [
        '## Proposed image updates',
        '',
        'Flux detected the following changes against `main`. This description is refreshed whenever Flux pushes to the update branch.',
        '',
    ]
    if rows:
        body += ['| Image | Change | Manifest |', '| --- | --- | --- |', *rows]
    else:
        body += ['No image-policy marker changes were found. Review the full diff for the proposed changes.']
    body += [
        '', '## Deployment and review', '',
        '- Merging this PR into `main` lets Flux reconcile the updated manifests and roll out the affected workloads.',
        '- Review the version changes above and upstream release notes for migration requirements. Digest changes without a tag change represent a new image revision under the same tag.',
        '- Check the Flux Local validation and rendered manifest diff on this PR before merging. This description does not report their results.',
        '- Home Assistant follows stable version tags; the Servarr policies follow `rolling` tags with pinned digests.',
        '', '## Changed manifests', '',
        *[f'- `{cell(filename)}`' for filename in files],
        '',
    ]
    output = Path(os.environ['RUNNER_TEMP'])
    (output / 'image-update-pr-title.txt').write_text(title + '\n')
    (output / 'image-update-pr-body.md').write_text('\n'.join(body))


if __name__ == '__main__':
    main()
