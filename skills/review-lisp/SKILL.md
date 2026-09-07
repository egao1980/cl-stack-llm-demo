---
name: review-lisp
description: >-
  How this workspace tests and packages first-party Common Lisp systems.
---

# Review a Lisp change

- Tests = **Rove**. New tables use `deftest-parametrize` (`egao1980/rove`).
- Errors = conditions + restarts (CLHS 9). Do not `handler-case` away a restart the caller should see.
- First-party `.asd` has no `:sources`. OCI is implied. Never `:sources (("foo" :ql))`.
- Name the packages: `steer-protocol` (`stack-steer`), `ai-agent-protocol` (`stack-ai-agent`).
