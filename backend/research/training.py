"""Train exactly two SVMs on one training-only, four-feature representation."""
import json
import os
import platform
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from importlib.metadata import version
import joblib
import numpy as np
from sklearn.feature_selection import SelectKBest, f_classif
from sklearn.impute import SimpleImputer
from sklearn.metrics import accuracy_score, balanced_accuracy_score, confusion_matrix, recall_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import MinMaxScaler
from sklearn.svm import SVC
from .data import HEART, NUMERIC, load_heart
from .quantum import QuantumKernelSVC

ARTIFACT_DIR = Path(os.environ.get('ARTIFACT_DIR', Path(__file__).resolve().parents[1] / 'artifacts' / 'heart-prototype'))


def evaluate(y, scores, threshold):
    predictions = scores >= threshold
    tn, fp, fn, tp = confusion_matrix(y, predictions, labels=[0, 1]).ravel()
    return {'accuracy': float(accuracy_score(y, predictions)),
            'sensitivity': float(recall_score(y, predictions)),
            'specificity': float(tn / (tn + fp)),
            'confusion_matrix': [[int(tn), int(fp)], [int(fn), int(tp)]],
            'test_rows': len(y), 'threshold': threshold}


def train(output=ARTIFACT_DIR):
    x, y, dataset = load_heart()
    ids = np.arange(len(y))
    development, test = train_test_split(ids, test_size=.2, stratify=y, random_state=42)
    training, validation = train_test_split(development, test_size=.25, stratify=y[development], random_state=42)
    # Select once on training data. Both models use precisely these four inputs.
    selection = Pipeline([('impute', SimpleImputer(strategy='median')),
                          ('select', SelectKBest(f_classif, k=4))])
    selection.fit(x.iloc[training][NUMERIC], y[training])
    names = np.asarray(NUMERIC)[selection['select'].get_support()].tolist()
    features = [next(f for f in HEART if f['name'] == name) for name in names]
    version_id = uuid.uuid4().hex
    metadata = {'version': version_id, 'created_at': datetime.now(timezone.utc).isoformat(),
                'task': 'heart', 'features': features, 'dataset': dataset,
                'split': {'seed': 42, 'train': training.tolist(), 'validation': validation.tolist(), 'test': test.tolist()},
                'selection': 'Training-only ANOVA selects four of five continuous UCI predictors',
                'score_type': 'decision margin', 'calibration': 'uncalibrated',
                'explanation': 'Exact interventional Shapley values over four inputs, averaged over eight training background records',
                'environment': {'python': platform.python_version(), 'platform': platform.platform(),
                                'packages': {p: version(p) for p in ['numpy', 'pandas', 'scikit-learn', 'qiskit', 'scipy']}},
                'comparison': []}
    fitted = {}
    for key, name, estimator in [('classical', 'Classical SVM', SVC(kernel='rbf', C=1.0)),
                                  ('quantum', 'Quantum-kernel SVM', QuantumKernelSVC())]:
        pipeline = Pipeline([('impute', SimpleImputer(strategy='median')),
                             ('scale', MinMaxScaler(feature_range=(0, np.pi), clip=True)),
                             ('model', estimator)])
        started = time.perf_counter()
        pipeline.fit(x.iloc[training][names], y[training])
        fit_seconds = time.perf_counter() - started
        validation_scores = pipeline.decision_function(x.iloc[validation][names])
        candidates = np.unique(np.r_[validation_scores, np.nextafter(validation_scores.max(), np.inf)])
        threshold = float(max(candidates, key=lambda t: (balanced_accuracy_score(y[validation], validation_scores >= t), -abs(t))))
        started = time.perf_counter()
        scores = pipeline.decision_function(x.iloc[test][names])
        inference_seconds = time.perf_counter() - started
        metrics = evaluate(y[test], scores, threshold)
        metadata['comparison'].append(dict(id=key, name=name, **metrics, fit_seconds=fit_seconds, test_inference_seconds=inference_seconds))
        fitted[key] = pipeline
        if key == 'quantum':
            metadata['quantum_resources'] = dict(estimator.resources_, circuit_evaluations=estimator.circuit_evaluations_)
        print(f'{name}: accuracy={metrics["accuracy"]:.3f}, sensitivity={metrics["sensitivity"]:.3f}, specificity={metrics["specificity"]:.3f}', flush=True)
    sample = json.loads(x.iloc[test[0]][names].to_json())
    bundle = {'metadata': metadata, 'models': fitted, 'selection': selection,
              'background': x.iloc[training[:8]][names].copy(), 'sample': sample,
              'sample_row': int(test[0]), 'sample_label': int(y[test[0]])}
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    # Immutable bundle followed by an atomic pointer update; failed training leaves the previous version usable.
    destination = output / f'{version_id}.joblib'
    joblib.dump(bundle, destination)
    manifest_path = output / 'latest.tmp'
    manifest_path.write_text(json.dumps({'version': version_id}), encoding='utf-8')
    manifest_path.replace(output / 'latest.json')
    (output / 'metrics.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    return bundle
