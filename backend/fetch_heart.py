"""Download the public UCI Cleveland benchmark and preserve source provenance."""
import hashlib
import io
import json
from pathlib import Path
from urllib.request import urlopen
from zipfile import ZipFile

import pandas as pd
from research.data import HEART, TASKS, parse_csv


def main():
    url = 'https://archive.ics.uci.edu/static/public/45/heart%2Bdisease.zip'
    with urlopen(url, timeout=60) as response:
        raw = response.read()
    with ZipFile(io.BytesIO(raw)) as archive:
        source = archive.read('processed.cleveland.data')
    frame = pd.read_csv(io.BytesIO(source), header=None, names=[f['name'] for f in HEART] + ['num'])
    normalized = frame.to_csv(index=False).encode()
    parse_csv(normalized, 'heart')
    directory = Path(__file__).resolve().parent / 'benchmarks'
    directory.mkdir(exist_ok=True)
    (directory / 'heart.csv').write_bytes(normalized)
    manifest = {k: TASKS['heart'][k] for k in ['source_url', 'citation', 'license']}
    manifest.update(download_url=url, download_sha256=hashlib.sha256(raw).hexdigest(),
                    source_file='processed.cleveland.data', source_sha256=hashlib.sha256(source).hexdigest(),
                    normalized_sha256=hashlib.sha256(normalized).hexdigest())
    (directory / 'heart.manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'Saved {len(frame)} Cleveland records and checksum manifest to {directory}')


if __name__ == '__main__':
    main()
