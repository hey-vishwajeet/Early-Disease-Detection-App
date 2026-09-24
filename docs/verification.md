# Verification of the simplified heart prototype

Verified locally on 24 September 2026 using Python 3.12 and Flutter 3.44.8.

- Exactly two models trained successfully with the same four selected inputs and 181/61/61 train/validation/test split.
- Five backend tests passed: real data and training-only preprocessing, identical model representations, saved-model reload, exact Shapley additivity, CSV validation, input validation, unavailable-model errors and real quantum state-overlap behavior.
- Three Flutter tests passed: Home -> Load Sample -> Analyze -> Results -> comparison; PDF generation from the actual saved result; server error handling.
- `flutter analyze --no-pub`: no issues found.
- `flutter build web`: succeeded. An unused Cupertino-font reference warning was emitted by the build; the application's Material icons rendered correctly in the browser.
- Browser check: three-screen white/blue interface, real sample, quantum inference, three signed influences, expanded measured comparison and PDF download action completed without console errors. The CSV template generated a download link with the correct filename; the in-app browser's download-event observer did not report a download event.
- The generated PDF was rendered with Poppler and visually inspected: one page, readable tables, no overflow or clipped content.

## Measured comparison

| Model | Accuracy | Sensitivity | Specificity |
|---|---:|---:|---:|
| Classical SVM | 88.5% | 85.7% | 90.9% |
| Quantum-kernel SVM | 78.7% | 71.4% | 84.8% |

The held-out set contains 61 records: 28 positive and 33 negative. The classical model performs better on this split. See `heart-benchmark.json` for exact metrics, thresholds, split rows, circuit resource measurements and environment.

The real held-out sample is age=59, trestbps=138, thalach=182, oldpeak=0. Its quantum score is approximately -0.5251 against a threshold of 0.1246, producing the benchmark class `Disease absent`. This is not a medical diagnosis. `test/fixtures/heart_result.json` preserves the actual result used for the PDF and UI regression tests.

Native Android/iOS/macOS builds, deployment, patient use and actual quantum hardware were not verified. No early-detection or quantum-advantage claim is supported by this small single-split experiment.
