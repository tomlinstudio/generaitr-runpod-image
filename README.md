# GENERAITR — RunPod Docker Image

ComfyUI-based Docker image for running GENERAITR on RunPod.

## Usage

Pull and run on RunPod using this image. Set environment variables to configure sync and startup behavior.

### Key environment variables

| Variable | Description |
|---|---|
| `GENERAITR_SYNC_REPO_URL` | Git repo URL to sync scripts from at startup |
| `GENERAITR_SYNC_REPO_REF` | Branch/ref to sync (default: `main`) |
| `COMFYUI_PORT` | Port for ComfyUI (default: `8190`) |
| `COMFYUI_STATE_DIR` | Persistent state directory (default: `/workspace/comfyui-state`) |
| `GENERAITR_AUTO_BOOTSTRAP_FRESH_NODE` | Set to `1` to run bootstrap script on first start |
| `INSTALL_SAGEATTENTION` | Set to `1` at build time to include SageAttention |

## Build

```bash
docker build -f Dockerfile -t generaitr-runpod .
```

With SageAttention:
```bash
docker build -f Dockerfile --build-arg INSTALL_SAGEATTENTION=1 -t generaitr-runpod .
```

## Files

- `Dockerfile` — image definition
- `entrypoint.sh` — startup script (state dir setup, model paths, ComfyUI launch)
