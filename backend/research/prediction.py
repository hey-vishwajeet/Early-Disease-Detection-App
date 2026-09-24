"""Reloadable inference with exact, bounded four-feature Shapley explanations."""
import csv
import io
import json
import math
import re
from pathlib import Path
import joblib
import numpy as np
import pandas as pd
from .training import ARTIFACT_DIR


class HeartService:
    def __init__(self, directory=ARTIFACT_DIR):
        self.directory = Path(directory)
        self.version = None
        self.bundle = None

    def load(self):
        pointer = self.directory / 'latest.json'
        if not pointer.exists():
            raise FileNotFoundError('The models are not ready yet. Run python backend/train_model.py first.')
        version = json.loads(pointer.read_text(encoding='utf-8'))['version']
        if not re.fullmatch('[a-f0-9]{32}', version):
            raise ValueError('Invalid model version')
        if self.version != version:
            self.bundle = joblib.load(self.directory / f'{version}.joblib')
            self.version = version
        return self.bundle

    def validate(self, values):
        bundle = self.load()
        names = [f['name'] for f in bundle['metadata']['features']]
        if not isinstance(values, dict) or set(values) != set(names):
            raise ValueError('Please supply these four measurements: ' + ', '.join(names))
        clean = {}
        for name in names:
            value = values[name]
            if value is None or value == '':
                clean[name] = None
                continue
            if isinstance(value, bool):
                raise ValueError(f'{name}: enter a number')
            try:
                value = float(value)
            except (TypeError, ValueError):
                raise ValueError(f'{name}: enter a number') from None
            if not math.isfinite(value) or value < 0:
                raise ValueError(f'{name}: enter a finite, non-negative number')
            clean[name] = value
        if all(v is None for v in clean.values()):
            raise ValueError('Enter at least one recorded measurement or choose Load Sample.')
        return clean

    def import_csv(self, text):
        reader = csv.DictReader(io.StringIO(text.lstrip('\ufeff')))
        names = reader.fieldnames or []
        if len(set(names)) != len(names):
            raise ValueError('The CSV has duplicate column names. Please use the template.')
        rows = list(reader)
        if len(rows) != 1:
            raise ValueError('Please import one assessment row at a time using the template.')
        return self.validate(rows[0])

    def template(self):
        bundle = self.load()
        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=[f['name'] for f in bundle['metadata']['features']])
        writer.writeheader()
        writer.writerow(bundle['sample'])
        return output.getvalue()

    def analyze(self, values):
        bundle = self.load()
        values = self.validate(values)
        metadata = bundle['metadata']
        features = metadata['features']
        names = [f['name'] for f in features]
        row = pd.DataFrame([values], columns=names, dtype=float)
        pipeline = bundle['models']['quantum']
        score = float(pipeline.decision_function(row)[0])
        threshold = next(m['threshold'] for m in metadata['comparison'] if m['id'] == 'quantum')
        present = score >= threshold
        explanation = shapley(pipeline, row, bundle['background'])
        contributions = [dict(f, input_value=values[f['name']], contribution=float(explanation['values'][i])) for i, f in enumerate(features)]
        contributions.sort(key=lambda f: abs(f['contribution']), reverse=True)
        label = 'Disease present' if present else 'Disease absent'
        return {'prediction': label, 'score': score, 'threshold': threshold,
                'score_type': 'Uncalibrated model score', 'probability': None,
                'summary': f'The quantum model classified this record as "{label.lower()}" using patterns learned from the UCI heart-disease benchmark. This is a research result, not a medical diagnosis.',
                'top_features': contributions[:3], 'all_contributions': contributions,
                'explanation': {'method': 'Exact four-feature interventional Shapley',
                                'baseline': explanation['baseline'], 'output_scale': 'decision margin',
                                'evaluations': explanation['evaluations'], 'background_rows': len(bundle['background'])},
                'input': values, 'imputed_fields': [n for n, v in values.items() if v is None],
                'model_version': metadata['version'], 'comparison': metadata['comparison'],
                'dataset': metadata['dataset'], 'features': features,
                'sample_partition': 'User input; Load Sample uses a held-out test record',
                'context': 'Diagnostic benchmark classification does not prove early detection or predict future disease. Quantum improvement is not assumed.'}


def shapley(pipeline, row, background):
    """Exact enumeration of 16 coalitions x 8 training background rows = 128 calls.

    Empirical interventional Shapley values in the complete pipeline's score units.
    This is exact for the chosen background distribution, not medical causation.
    """
    names = list(row.columns)
    n = len(names)
    paths = []
    for mask in range(1 << n):
        for _, base in background.iterrows():
            point = base.copy()
            for i, name in enumerate(names):
                if mask & (1 << i):
                    point[name] = row.iloc[0][name]
            paths.append(point)
    scores = pipeline.decision_function(pd.DataFrame(paths, columns=names)).reshape(1 << n, len(background)).mean(axis=1)
    effects = np.zeros(n)
    for i in range(n):
        for mask in range(1 << n):
            if mask & (1 << i):
                continue
            size = mask.bit_count()
            weight = math.factorial(size) * math.factorial(n - size - 1) / math.factorial(n)
            effects[i] += weight * (scores[mask | (1 << i)] - scores[mask])
    return {'values': effects, 'baseline': float(scores[0]), 'evaluations': len(paths)}
