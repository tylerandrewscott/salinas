# spaCy Transformer on Apple Silicon GPU (M-series Mac)

## Goal
Run `en_core_web_trf` using the Metal Performance Shaders (MPS) GPU backend on an Apple Silicon Mac.

## Requirements
- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 12.3+
- Conda (Miniconda or Anaconda) — use the arm64 installer

---

## Setup Steps

### 1. Create a dedicated conda environment
```bash
conda create -n spacy-env python=3.11
conda activate spacy-env
```

### 2. Install spaCy and curated transformers via conda-forge
```bash
conda install -c conda-forge spacy spacy-curated-transformers
```

### 3. Download the transformer model
```bash
python -m spacy download en_core_web_trf
```

### 4. Install thinc-apple-ops via pip (not available on conda-forge)
```bash
pip install thinc-apple-ops
```

### 5. Set the MPS fallback environment variable permanently
```bash
conda env config vars set PYTORCH_ENABLE_MPS_FALLBACK=1
conda activate spacy-env  # re-activate to apply the variable
```

---

## Usage

```python
import spacy
from thinc.api import get_current_ops

spacy.require_gpu()
print('Thinc ops:', get_current_ops().__class__.__name__)  # Should print: MPSOps

nlp = spacy.load("en_core_web_trf")
doc = nlp("Apple is looking at buying a U.K. startup for $1 billion.")
print([(ent.text, ent.label_) for ent in doc.ents])
```

---

## Verification Checklist
- `get_current_ops().__class__.__name__` prints `MPSOps` ✅
- `spacy.__version__` is 3.7 or higher ✅
- `nlp.pipe_names` includes `transformer` (backed by `CuratedTransformer`) ✅

---

## Notes
- The pipeline component is still named `"transformer"` but is backed by
  `spacy_curated_transformers.pipeline.transformer.CuratedTransformer` (spaCy v3.7+).
  Confirm with: `print(type(nlp.get_pipe("transformer")))`
- Do NOT use `pip install spacy` directly on Apple Silicon — compiled dependencies
  like `blis` will fail to build. Always use conda-forge for spaCy.
- `thinc-apple-ops` is what enables MPSOps. Without it, spaCy falls back to CPU even
  if `spacy.require_gpu()` is called.
- `PYTORCH_ENABLE_MPS_FALLBACK=1` is needed because some PyTorch ops are not yet
  implemented in MPS and will error without the fallback.
- If running without the permanent env var set, prefix your command:
  `PYTORCH_ENABLE_MPS_FALLBACK=1 python your_script.py`
