;;;; Live embed canary: LM Studio /v1/embeddings (bge + qwen), then llama.cpp, then vllm.cpp.
;;;;
;;;;   CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/smoke-embed.lisp
;;;;
;;;; Loads workspace .env (LM_API_TOKEN / OPENAI_*). vllm load/arch refusals SKIP.

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&SMOKE FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-stack-llm-demo/openai")

(in-package #:cl-user)

(let ((env (cl-stack-llm-demo:find-and-apply-dotenv)))
  (format t "~&dotenv=~s models=~s~%"
          (and env (namestring env))
          (cl-stack-llm-demo:lmstudio-embed-models)))

(cl-stack-llm-demo:with-http-runtime
  (cl-stack-llm-demo:run-lmstudio-embed-smoke))

(asdf:load-system "cl-stack-llm-demo/llama")
(format t "~&llama-available=~s ggufs=~s~%"
        (llama-cpp:llama-available-p)
        (cl-stack-llm-demo:find-lmstudio-embed-ggufs))
(cl-stack-llm-demo:run-llama-embed-smoke)

(asdf:load-system "cl-stack-llm-demo/vllm")
(format t "~&vllm-available=~s~%"
        (vllm-cpp:vllm-available-p))
(cl-stack-llm-demo:run-vllm-embed-smoke)

(format t "~&SMOKE OK~%")
(uiop:quit 0)
