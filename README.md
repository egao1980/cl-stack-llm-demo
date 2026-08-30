# cl-stack-llm-demo

Public canary for [`llm-protocol-vllm-cpp`](https://github.com/egao1980/llm-protocol-vllm-cpp): native **vllm.cpp** + an **MCP** tool that **samples** + an **`ai-agent-protocol`** desk agent.

Clone this repo only. Deps come from [`ghcr.io/egao1980/cl-systems`](https://github.com/egao1980/cl-systems) via [`cl-repository-client`](https://github.com/egao1980/cl-repository) walking the `.asd`. No sibling checkouts.

```
LM Studio GGUF ──► vllm.cpp ──► llm-protocol-vllm-cpp
                                    │
                         GENERATE ──┤
                                    │
     MCP support-desk               │
       draft_reply ── request-sampling ──► host create-message ──► GENERATE
                                    │
     agent "desk" ── lookup_order / lookup_kb (CL) + draft_reply (MCP)
```

`cl-stack-llm-demo` itself does **not** depend on `vllm-cpp` (that would pull the linux/amd64 CUDA overlay on every install). Live path is `cl-stack-llm-demo/vllm`; `scripts/install.lisp` walks both systems.

## Prereqs

| Tool | Notes |
|------|--------|
| [Roswell](https://roswell.github.io/) + SBCL | `ros install sbcl-bin` |
| [oras](https://oras.land/) | client + package pull |

## Install

```bash
git clone https://github.com/egao1980/cl-stack-llm-demo
cd cl-stack-llm-demo
./scripts/setup-client.sh      # cl-repository-client → ./.cl-repository
ros -l scripts/install.lisp    # .asd deps from GHCR (incl. vllm-cpp overlay)
```

## Mock (no GPU)

```bash
ros -l scripts/run-mock.lisp
```

## Live (Mac + LM Studio GGUF)

Picks an LM Studio GGUF this **libvllm overlay can actually load**. `vllm-cpp:0.1.1` darwin only speaks GGUF families `qwen35` / `qwen35moe` / `qwen3next` / `deepseek4` / `muse-glimmer`. Local Nemotron (`nemotron_h` + ggml type 6), Gemma, and OCR files are skipped. Prefers **Qwen3.5-2B Q4_K_M** (~1.2GB; 0.8B is the fallback). Override with `VLLM_MODEL_PATH`.

```bash
# if you only have Nemotron/Gemma downloaded:
mkdir -p ~/.lmstudio/models/lmstudio-community/Qwen3.5-2B-GGUF
curl -L -o ~/.lmstudio/models/lmstudio-community/Qwen3.5-2B-GGUF/Qwen3.5-2B-Q4_K_M.gguf \
  https://huggingface.co/lmstudio-community/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf

ros -l scripts/smoke.lisp   # generate pong
ros -l scripts/demo.lisp    # generate + sampling + agent
```

What it runs:

1. `generate` smoke (`pong`)
2. MCP `draft_reply` → `request-sampling` → same engine
3. Agent usecases (lookup + draft)

| Id | Prompt |
|----|--------|
| `late-shipment` | order 1001 late keyboard |
| `refund` | order 1002 wrong SKU |
| `password-reset` | locked out, no order |

## Env

| Variable | Meaning |
|----------|---------|
| `VLLM_MODEL_PATH` | GGUF or HF dir |
| `VLLM_DEVICE` | `auto` / `cpu` / `cuda` |
| `VLLM_CPP_NATIVE` | directory with `libvllm.dylib` (optional; overlay is enough) |
| `CL_REPOSITORY_CLIENT_DIR` | already-extracted client tree |

Part of [cl-stack](https://github.com/egao1980/cl-stack).

## License

MIT — see [LICENSE](LICENSE).
