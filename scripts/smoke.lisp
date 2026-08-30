;;;; Load vllm.cpp + one short generate.
;;;;   ./scripts/setup-client.sh && ros -l scripts/install.lisp
;;;;   ros -l scripts/smoke.lisp

(load (merge-pathnames "bootstrap.lisp" *load-truename*))
(load-demo-init-files :live t)

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&SMOKE FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-stack-llm-demo/vllm")

(in-package #:cl-user)

(format t "~&available=~s path=~s~%"
        (vllm-cpp:vllm-available-p)
        (cl-stack-llm-demo:find-lmstudio-model))
(unless (vllm-cpp:vllm-available-p)
  (error "libvllm not available"))
(let ((b (cl-stack-llm-demo:make-vllm-backend :max-model-len 1024)))
  (unwind-protect
       (let ((r (llm-protocol:generate
                 b "Reply with the single word pong and nothing else."
                 :settings (llm-protocol:make-llm-settings :temperature 0 :max-tokens 16))))
         (format t "~&SMOKE TEXT=~s finish=~s~%"
                 (llm-protocol:llm-response-text r)
                 (llm-protocol:llm-response-finish-reason r))
         (unless (plusp (length (or (llm-protocol:llm-response-text r) "")))
           (error "empty generate")))
    (llm-protocol-vllm-cpp:close-vllm-cpp-backend b)))
(format t "~&SMOKE OK~%")
(uiop:quit 0)
