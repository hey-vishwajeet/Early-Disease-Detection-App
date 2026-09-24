"""UCI Cleveland schema; this prototype supports heart disease only."""
import hashlib
import io
import json
from pathlib import Path
import numpy as np
import pandas as pd

HEART = [
    {'name': 'age', 'label': 'Age', 'unit': 'years', 'help': 'Age at the time of the recorded examination.', 'choices': None},
    {'name': 'sex', 'label': 'Sex', 'unit': '', 'choices': [0, 1]},
    {'name': 'cp', 'label': 'Chest pain type', 'unit': '', 'choices': [1, 2, 3, 4]},
    {'name': 'trestbps', 'label': 'Resting blood pressure', 'unit': 'mmHg', 'help': 'Resting systolic blood pressure recorded on hospital admission.', 'choices': None},
    {'name': 'chol', 'label': 'Serum cholesterol', 'unit': 'mg/dL', 'help': 'Serum cholesterol from the recorded blood test.', 'choices': None},
    {'name': 'fbs', 'label': 'Fasting blood sugar >120 mg/dL', 'unit': '', 'choices': [0, 1]},
    {'name': 'restecg', 'label': 'Resting ECG', 'unit': '', 'choices': [0, 1, 2]},
    {'name': 'thalach', 'label': 'Maximum exercise heart rate', 'unit': 'bpm', 'help': 'Highest heart rate reached during an exercise test, not resting heart rate.', 'choices': None},
    {'name': 'exang', 'label': 'Exercise-induced angina', 'unit': '', 'choices': [0, 1]},
    {'name': 'oldpeak', 'label': 'ST depression during exercise', 'unit': 'recorded ST value', 'help': 'Exercise-induced ST depression relative to rest. Copy the ECG test value.', 'choices': None},
    {'name': 'slope', 'label': 'ST slope', 'unit': '', 'choices': [1, 2, 3]},
    {'name': 'ca', 'label': 'Major vessels', 'unit': '', 'choices': [0, 1, 2, 3]},
    {'name': 'thal', 'label': 'Thal', 'unit': '', 'choices': [3, 6, 7]},
]
TASK = {'id': 'heart', 'name': 'Heart disease', 'features': HEART,
        'target': 'num', 'labels': ['Disease absent', 'Disease present'],
        'target_definition': 'UCI num=0: absence; num=1,2,3,4: presence of angiographic heart disease.',
        'source_url': 'https://archive.ics.uci.edu/dataset/45/heart+disease',
        'citation': 'Janosi et al. (1989), doi:10.24432/C52P4X', 'license': 'CC BY 4.0'}
TASKS = {'heart': TASK}
NUMERIC = [f['name'] for f in HEART if f['choices'] is None]
DATA_DIR = Path(__file__).resolve().parents[1] / 'benchmarks'


def parse_csv(raw, task_id='heart'):
    if task_id != 'heart':
        raise ValueError('This prototype supports heart disease only')
    frame = pd.read_csv(io.BytesIO(raw), na_values=['?', 'NA', ''])
    if list(frame.columns) != [f['name'] for f in HEART] + ['num']:
        raise ValueError('Expected the original 13 Cleveland feature columns followed by num')
    if len(frame) != 303:
        raise ValueError('Expected the 303-record UCI Cleveland benchmark')
    target = pd.to_numeric(frame.pop('num'), errors='raise')
    if not target.isin([0, 1, 2, 3, 4]).all():
        raise ValueError('Cleveland labels must be 0,1,2,3,4, with no missing labels')
    for feature in HEART:
        col = pd.to_numeric(frame[feature['name']], errors='raise')
        if np.isinf(col).any() or col.isna().all():
            raise ValueError('Feature columns must contain finite measurements')
        if feature['choices'] and not col.dropna().isin(feature['choices']).all():
            raise ValueError('Invalid original UCI category code: ' + feature['name'])
        frame[feature['name']] = col.astype(float)
    return frame, (target > 0).astype(int).to_numpy(), {'rows': len(frame),
        'sha256': hashlib.sha256(raw).hexdigest(), 'quality': {'missing': frame.isna().sum().to_dict()},
        'target_definition': TASK['target_definition']}


def load_heart():
    raw = (DATA_DIR / 'heart.csv').read_bytes()
    manifest = json.loads((DATA_DIR / 'heart.manifest.json').read_text(encoding='utf-8'))
    if hashlib.sha256(raw).hexdigest() != manifest['normalized_sha256']:
        raise ValueError('Benchmark checksum mismatch. Run python backend/fetch_heart.py again.')
    x, y, quality = parse_csv(raw)
    return x, y, dict(quality, source=manifest)
