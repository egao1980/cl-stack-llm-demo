(in-package #:cl-stack-llm-demo)

(defmacro with-http-runtime (&body body)
  "Bind http-backend-async × libuv so LM Studio /embeddings works."
  `(progn
     (setf http-backend-async:*event-backend-maker*
           #'event-backend-libuv:make-libuv-backend)
     (let* ((eb (event-backend-libuv:make-libuv-backend))
            (el (event-protocol:make-event-loop eb)))
       (event-protocol:with-event-backend (eb)
         (event-protocol:with-event-loop-var (el)
           (let ((http-protocol:*http-backend* (http-backend-async:make-async-backend)))
             ,@body))))))

(defun make-lmstudio-backend (&key base-url api-key default-model embedding-model)
  (llm-protocol-openai:make-openai-compat-backend
   :base-url (or base-url (%env "OPENAI_BASE_URL") (%env "LM_STUDIO_BASE_URL"))
   :api-key (or api-key (%env "OPENAI_API_KEY") (%env "LM_API_TOKEN"))
   :default-model (or default-model (%env "OPENAI_MODEL") "local-model")
   :embedding-model embedding-model))

(defun run-lmstudio-embed-smoke (&key (models (lmstudio-embed-models)))
  "POST /v1/embeddings for each LM Studio embedding model. Fail-fast."
  (unless models
    (error "no embedding models — set LM_EMBED_MODELS"))
  (dolist (model models)
    (let ((b (make-lmstudio-backend :embedding-model model)))
      (format t "~&-- lmstudio embed model=~s~%" model)
      (let ((r (llm-protocol:embed b "hello from cl-stack")))
        (multiple-value-bind (n dim) (%assert-embed-result r model)
          (format t "~&   one: n=~a dim=~a wire-model=~s~%"
                  n dim (llm-protocol:llm-embed-result-model r))))
      (let ((r (llm-protocol:embed b '("alpha" "beta"))))
        (multiple-value-bind (n dim) (%assert-embed-result r (format nil "~a/many" model))
          (unless (= n 2)
            (error "expected 2 embeddings for ~a, got ~a" model n))
          (format t "~&   many: n=~a dim=~a~%" n dim)))
      (let ((v (llm-protocol:embed-query b "query")))
        (unless (and (vectorp v) (plusp (length v)))
          (error "embed-query empty for ~a" model))
        (format t "~&   query: dim=~a~%" (length v)))))
  t)
