# Model Files Directory

This directory is intended to store the AI model files used by the Video Face Swap API. Due to the large size of these model files, they are managed using Git Large File Storage (Git LFS).

## Model Files

When the application runs for the first time, it will automatically download the required model files. These files include:

- Face detection models (SCRFD)
- Face recognition models (ArcFace)
- Face swapping models (InsightFace)

The models are typically in formats such as:
- `.onnx` (Open Neural Network Exchange)
- `.pth` (PyTorch)
- `.bin` (Binary files)

## Using Git LFS

Git LFS (Large File Storage) is used to efficiently handle these large model files. Before working with this repository, make sure to:

1. Install Git LFS
   ```bash
   git lfs install
   ```

2. After cloning the repository
   ```bash
   git lfs pull
   ```

## Note on Model Storage

- Models will be cached in the `.cache` directory inside the container
- During build time, models are pre-downloaded to optimize runtime performance
- The container will download any missing models on first run

## Manual Model Management

If you need to manually download or update models, you can use the InsightFace library's utilities:

```python
import insightface
from insightface.app import FaceAnalysis

# Initialize with CPU provider
app = FaceAnalysis(providers=['CPUExecutionProvider'])

# Prepare models - this will download them if not present
app.prepare(ctx_id=0, det_size=(640, 640))
```

This will download and prepare all necessary models for face analysis.
