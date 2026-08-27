;;;; Live vllm.cpp + MCP sampling + support-desk agent.
;;;;
;;;;   CL_SOURCE_REGISTRY="$PWD/../:" ros -l scripts/demo.lisp
;;;;
;;;; Optional: VLLM_MODEL_PATH=/path/to/model.gguf  VLLM_DEVICE=auto

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&DEMO FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-stack-llm-demo/vllm")

(in-package #:cl-user)

(cl-stack-llm-demo:run-live)
(format t "~&DEMO OK~%")
(uiop:quit 0)
