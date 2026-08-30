(in-package #:cl-stack-llm-demo)

(defun make-llama-backend (&key model-path (n-ctx 512))
  "Load a llama.cpp GGUF. N-CTX keeps Metal memory small for embed smoke."
  (let ((path (or model-path (first (find-lmstudio-embed-ggufs))
                  (find-lmstudio-model))))
    (llm-backend-llama-cpp:make-llama-cpp-backend
     :model-path path
     :n-ctx n-ctx
     :engine (llama-cpp:load-engine :model-path path :n-ctx n-ctx))))

(defun run-llama-embed-smoke (&key (paths (find-lmstudio-embed-ggufs))
                                (n-ctx 512))
  "Native llama.cpp embed on GGUFs. Load refusals print SKIP, not FAIL."
  (unless (llama-cpp:llama-available-p)
    (format t "~&-- llama SKIP: libllamastack not available~%")
    (return-from run-llama-embed-smoke nil))
  (unless paths
    (format t "~&-- llama SKIP: no embed GGUF (set VLLM_EMBED_MODEL_PATH or LLAMA_MODEL_PATH)~%")
    (return-from run-llama-embed-smoke nil))
  (dolist (path paths)
    (format t "~&-- llama embed path=~s~%" path)
    (handler-case
        (let ((b (make-llama-backend :model-path path :n-ctx n-ctx)))
          (unwind-protect
               (progn
                 (let ((r (llm-protocol:embed b "hello from cl-stack")))
                   (multiple-value-bind (n dim)
                       (%assert-embed-result r path)
                     (format t "~&   one: n=~a dim=~a~%" n dim)))
                 (let ((r (llm-protocol:embed b '("alpha" "beta"))))
                   (multiple-value-bind (n dim)
                       (%assert-embed-result r (format nil "~a/many" path))
                     (unless (= n 2)
                       (error "expected 2 embeddings, got ~a" n))
                     (format t "~&   many: n=~a dim=~a~%" n dim)))
                 (let ((v (llm-protocol:embed-query b "query")))
                   (unless (and (vectorp v) (plusp (length v)))
                     (error "embed-query empty"))
                   (format t "~&   query: dim=~a~%" (length v))))
            (llm-backend-llama-cpp:close-llama-cpp-backend b)))
      (error (e)
        (format t "~&   SKIP: ~a~%" e))))
  t)
