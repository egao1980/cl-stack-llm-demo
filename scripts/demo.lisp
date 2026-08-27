;;;; Live vllm.cpp + MCP sampling + support-desk agent.
;;;;   ./scripts/setup-client.sh && ros -l scripts/install.lisp
;;;;   ros -l scripts/demo.lisp
;;;;
;;;; Optional: VLLM_MODEL_PATH=/path/to/model.gguf  VLLM_DEVICE=auto

(load (merge-pathnames "bootstrap.lisp" *load-truename*))

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&DEMO FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-stack-llm-demo/vllm")

(in-package #:cl-user)

(format t "~&demo: model=~s~%" (cl-stack-llm-demo:find-lmstudio-model))
(cl-stack-llm-demo:run-live)
(format t "~&DEMO OK~%")
(uiop:quit 0)
