# cl-stack-llm-demo

Canary for [`llm-backend-vllm-cpp`](https://github.com/egao1980/llm-backend-vllm-cpp): native **vllm.cpp** + an **MCP** tool that **samples** + an **`ai-agent-protocol`** desk agent.

```
LM Studio GGUF ──► vllm.cpp ──► llm-backend-vllm-cpp
                                    │
                         GENERATE ──┤
                                    │
     MCP support-desk               │
       draft_reply ── request-sampling ──► host create-message ──► GENERATE
                                    │
     agent "desk" ── lookup_order / lookup_kb (CL) + draft_reply (MCP)
```

`cl-stack-llm-demo` itself does **not** depend on `vllm-cpp` (that would pull the linux/amd64 CUDA overlay). Live path is `cl-stack-llm-demo/vllm`. Local-only — no GitHub Actions.

## Mock (no GPU)

```bash
CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/run-mock.lisp
# or
CL_SOURCE_REGISTRY="$PWD/../:" ros -e '(asdf:test-system "cl-stack-llm-demo")' -q
```

## Live (Mac + LM Studio GGUF)

Picks an LM Studio GGUF this **libvllm overlay can actually load**. `vllm-cpp:0.1.1` darwin only speaks GGUF families `qwen35` / `qwen35moe` / `qwen3next` / `deepseek4` / `muse-glimmer`. Local Nemotron (`nemotron_h` + ggml type 6), Gemma, and OCR files are skipped. Prefers **Qwen3.5-2B Q4_K_M** (~1.2GB; 0.8B is the fallback). Override with `VLLM_MODEL_PATH`.

```bash
# if you only have Nemotron/Gemma downloaded:
mkdir -p ~/.lmstudio/models/lmstudio-community/Qwen3.5-2B-GGUF
curl -L -o ~/.lmstudio/models/lmstudio-community/Qwen3.5-2B-GGUF/Qwen3.5-2B-Q4_K_M.gguf \
  https://huggingface.co/lmstudio-community/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf
```

Needs `libvllm` (OCI overlay `vllm-cpp:0.1.1` darwin/arm64, or `VLLM_CPP_NATIVE`).

```bash
# one-time overlay into the sibling checkout (gitignored):
oras pull ghcr.io/egao1980/cl-systems/vllm-cpp:0.1.1 --platform darwin/arm64 -o /tmp/vllm-cpp-oci
tar -xzf /tmp/vllm-cpp-oci/native-library.tar.gz -C /tmp/vllm-cpp-native
cp /tmp/vllm-cpp-native/vllm-cpp-0.1.1/native/* ../vllm-cpp/native/

CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/smoke.lisp         # generate pong
CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/smoke-embed.lisp   # embed: LM Studio + vllm.cpp
CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/demo.lisp          # generate + sampling + agent
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

## Embed smoke

Local-only. Hits LM Studio `POST /v1/embeddings` for **bge-m3** and **qwen3-embedding-0.6b**, then tries native `vllm_embed` on the matching GGUFs. Darwin overlay 0.1.1 may refuse embedding checkpoints (not pooling / unknown GGUF family) — those print `SKIP`, not fail. Needs workspace `.env` (`LM_API_TOKEN` / `OPENAI_*`).

```bash
CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/smoke-embed.lisp
```

| Id | Path |
|----|------|
| LM Studio | `text-embedding-bge-m3`, `text-embedding-qwen3-embedding-0.6b` |
| vllm.cpp | `Qwen3-Embedding-0.6B-Q8_0.gguf`, `bge-m3-Q8_0.gguf` |

## Env

| Variable | Meaning |
|----------|---------|
| `VLLM_MODEL_PATH` | GGUF or HF dir |
| `VLLM_EMBED_MODEL_PATH` | comma-separated embed GGUFs |
| `VLLM_DEVICE` | `auto` / `cpu` / `cuda` |
| `VLLM_CPP_NATIVE` | directory with `libvllm.dylib` |
| `LLM_DEMO_ENV` | path to a `.env` |
| `LM_EMBED_MODELS` | comma-separated LM Studio embedding ids |
| `OPENAI_BASE_URL` / `OPENAI_API_KEY` / `LM_API_TOKEN` | LM Studio `/v1` |

Part of [cl-stack](https://github.com/egao1980/cl-stack).

## License

MIT — see [LICENSE](LICENSE).
