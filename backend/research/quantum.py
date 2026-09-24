"""Exact Qiskit statevector fidelity kernel with a classical SVM optimizer."""
import numpy as np
from qiskit import QuantumCircuit
from qiskit.quantum_info import Statevector
from sklearn.base import BaseEstimator, ClassifierMixin
from sklearn.svm import SVC


def feature_circuit(values, repetitions=2):
    circuit = QuantumCircuit(len(values))
    for _ in range(repetitions):
        for q, angle in enumerate(values):
            circuit.h(q)
            circuit.ry(float(angle), q)
            circuit.rz(float(angle * angle), q)
        for q in range(len(values) - 1):
            circuit.cx(q, q + 1)
    return circuit


class StatevectorBackend:
    name = 'qiskit.quantum_info.Statevector (exact, noiseless CPU simulator)'

    def states(self, x):
        return np.asarray([Statevector.from_instruction(feature_circuit(row)).data for row in x])


class QuantumKernelSVC(ClassifierMixin, BaseEstimator):
    def __init__(self, C=1.0):
        self.C = C

    def fit(self, x, y):
        self.backend_ = StatevectorBackend()
        self.states_ = self.backend_.states(x)
        self.circuit_evaluations_ = len(x)
        self.svc_ = SVC(kernel='precomputed', C=self.C).fit(self.kernel(self.states_, self.states_), y)
        self.classes_ = self.svc_.classes_
        self.resources_ = dict(backend=self.backend_.name, qubits=x.shape[1],
                               depth=feature_circuit(x[0]).depth(), repetitions=2,
                               entanglement='linear CNOT chain', shots=None, noise='none',
                               optimizer='libsvm dual optimization',
                               circuit=str(feature_circuit(x[0])),
                               feature_map='Two repetitions: H, RY(x), RZ(x²), linear CX')
        return self

    @staticmethod
    def kernel(left, right):
        return np.clip(np.abs(left.conj() @ right.T) ** 2, 0, 1)

    def decision_function(self, x):
        states = self.backend_.states(x)
        self.circuit_evaluations_ += len(x)
        return self.svc_.decision_function(self.kernel(states, self.states_))

    def predict(self, x):
        return (self.decision_function(x) >= 0).astype(int)
