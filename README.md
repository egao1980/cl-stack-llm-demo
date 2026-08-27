# cl-stack-llm-demo

Canary for [`llm-protocol-vllm-cpp`](https://github.com/egao1980/llm-protocol-vllm-cpp): native **vllm.cpp** + an **MCP** tool that **samples** + an **`ai-agent-protocol`** desk agent.

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

`cl-stack-llm-demo` itself does **not** depend on `vllm-cpp` (CI would pull the linux/amd64 CUDA overlay). Live path is `cl-stack-llm-demo/vllm`.

## Mock (CI / no GPU)

```bash
CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/run-mock.lisp
# or
CL_SOURCE_REGISTRY="$PWD/../:" ros -e '(asdf:test-system "cl-stack-llm-demo")' -q
```

## Live (Mac + LM Studio GGUF)

Picks the smallest chat GGUF under `~/.lmstudio/models` (prefers **Nemotron 3 Nano 4B Q4_K_M**, skips embed/OCR/mmproj). Override with `VLLM_MODEL_PATH`.

Needs `libvllm` (OCI overlay `vllm-cpp:0.1.1` darwin/arm64, or `VLLM_CPP_NATIVE`).

```bash
# one-time overlay into the sibling checkout (gitignored):
oras pull ghcr.io/egao1980/cl-systems/vllm-cpp:0.1.1 --platform darwin/arm64 -o /tmp/vllm-cpp-oci
tar -xzf /tmp/vllm-cpp-oci/native-library.tar.gz -C /tmp/vllm-cpp-native
cp /tmp/vllm-cpp-native/vllm-cpp-0.1.1/native/* ../vllm-cpp/native/

CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/demo.lisp
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
| `VLLM_CPP_NATIVE` | directory with `libvllm.dylib` |

Part of [cl-stack](https://github.com/egao1980/cl-stack).

## License

MIT — see [LICENSE](LICENSE).
