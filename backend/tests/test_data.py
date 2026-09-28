import json

import pytest

from research import data


@pytest.mark.parametrize('newline', [b'\n', b'\r\n'])
def test_benchmark_checksum_across_platforms(tmp_path, monkeypatch, newline):
    raw = (data.DATA_DIR / 'heart.csv').read_bytes().replace(b'\r\n', b'\n')
    manifest = (data.DATA_DIR / 'heart.manifest.json').read_bytes()
    (tmp_path / 'heart.csv').write_bytes(raw.replace(b'\n', newline))
    (tmp_path / 'heart.manifest.json').write_bytes(manifest)
    monkeypatch.setattr(data, 'DATA_DIR', tmp_path)
    x, y, metadata = data.load_heart()
    assert len(x) == 303 and y.sum() == 139
    assert metadata['sha256'] == json.loads(manifest)['normalized_sha256']
    # Newline conversion is allowed; changing a measurement must still fail.
    altered = raw.replace(b'63.0', b'64.0', 1)
    assert altered != raw
    (tmp_path / 'heart.csv').write_bytes(altered)
    with pytest.raises(ValueError, match='checksum mismatch'):
        data.load_heart()
