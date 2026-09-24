import io
import json
import joblib
import numpy as np
import pandas as pd
import pytest
from app import create_app
from research.data import NUMERIC, load_heart
from research.prediction import HeartService
from research.quantum import QuantumKernelSVC, StatevectorBackend
from research.training import train


@pytest.fixture(scope='module')
def trained(tmp_path_factory):
    directory = tmp_path_factory.mktemp('heart')
    bundle = train(directory)
    return directory, bundle


def test_real_dataset_and_fair_training(trained):
    directory, bundle = trained
    x, y, dataset = load_heart()
    assert len(x) == 303 and y.sum() == 139
    meta = bundle['metadata']
    assert len(meta['comparison']) == 2
    names = [f['name'] for f in meta['features']]
    assert len(names) == 4 and names == ['age', 'trestbps', 'thalach', 'oldpeak']
    train_ids, val_ids, test_ids = [set(meta['split'][key]) for key in ['train', 'validation', 'test']]
    assert not train_ids & val_ids and not train_ids & test_ids and not val_ids & test_ids
    assert len(train_ids) + len(val_ids) + len(test_ids) == 303
    assert np.allclose(bundle['selection']['impute'].statistics_, x.iloc[sorted(train_ids)][NUMERIC].median())
    for pipeline in bundle['models'].values():
        assert np.allclose(pipeline['impute'].statistics_, x.iloc[sorted(train_ids)][names].median())
    classical = bundle['models']['classical'][:-1].transform(x[names])
    quantum = bundle['models']['quantum'][:-1].transform(x[names])
    assert np.allclose(classical, quantum)
    assert bundle['sample_row'] in test_ids
    assert meta['quantum_resources']['qubits'] == 4


def test_sample_prediction_explanation_reload(trained):
    directory, bundle = trained
    api = create_app(HeartService(directory)).test_client()
    config = api.get('/api/config')
    assert config.status_code == 200
    sample = api.get('/api/sample').json
    assert sample['partition'] == 'held-out test'
    result = api.post('/api/analyze', json={'features': sample['features']})
    assert result.status_code == 200, result.json
    result = result.json
    assert result['probability'] is None and len(result['top_features']) == 3
    reconstructed = result['explanation']['baseline'] + sum(f['contribution'] for f in result['all_contributions'])
    assert reconstructed == pytest.approx(result['score'], abs=1e-9)
    assert result['explanation']['evaluations'] == 128
    again = HeartService(directory).analyze(sample['features'])
    assert again['score'] == pytest.approx(result['score'])
    assert result['model_version'] == bundle['metadata']['version']


def test_csv_and_validation(trained):
    directory, bundle = trained
    api = create_app(HeartService(directory)).test_client()
    template = api.get('/api/template')
    assert template.status_code == 200 and 'attachment' in template.headers['Content-Disposition']
    imported = api.post('/api/import', json={'csv': template.text})
    assert imported.json['features'] == bundle['sample']
    lines = template.text.splitlines()
    assert api.post('/api/import', json={'csv': '\n'.join(lines + [lines[1]])}).status_code == 400
    assert api.post('/api/import', json={'csv': 'age,age\n40,41'}).status_code == 400
    assert api.post('/api/analyze', json={'features': {'age': 30}}).status_code == 400
    for value in [-1, 'nan', 'inf', True, 'not-a-number']:
        values = dict(bundle['sample'], age=value)
        assert api.post('/api/analyze', json={'features': values}).status_code == 400
    assert api.post('/api/analyze', json={'features': {k: None for k in bundle['sample']}}).status_code == 400
    assert api.post('/api/analyze', json=[]).status_code == 400
    values = dict(bundle['sample'], age=None)
    result = api.post('/api/analyze', json={'features': values})
    assert result.status_code == 200 and result.json['imputed_fields'] == ['age']


def test_no_synthetic_fallback(tmp_path):
    api = create_app(HeartService(tmp_path)).test_client()
    assert api.get('/health').status_code == 200
    assert api.get('/api/config').status_code == 503
    assert api.post('/predict', json={}).status_code == 410
    assert api.get('/v2/tasks').status_code == 404


def test_quantum_kernel_is_state_overlap():
    x = np.array([[.2, .4, .3, .6], [1.1, 2.3, .4, .8]])
    states = StatevectorBackend().states(x)
    gram = QuantumKernelSVC.kernel(states, states)
    assert np.allclose(np.diag(gram), 1)
    assert np.allclose(gram, gram.T)
    assert np.linalg.eigvalsh(gram).min() > -1e-10
    assert not np.allclose(gram, np.ones_like(gram))

