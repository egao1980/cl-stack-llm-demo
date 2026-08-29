(defpackage #:cl-stack-llm-demo
  (:use #:cl)
  (:nicknames #:stack-llm-demo)
  (:export #:*host-client*
           #:*max-sample-tokens*
           #:*usecases*
           #:decode-args
           #:lookup-order
           #:lookup-kb
           #:desk-mcp-source
           #:make-support-desk-server
           #:make-host-client
           #:sample-text
           #:call-draft-reply
           #:make-desk-agent
           #:with-demo-loop
           #:find-lmstudio-model
           #:find-lmstudio-embed-ggufs
           #:list-lmstudio-ggufs
           #:gguf-architecture
           #:*vllm-gguf-architectures*
           #:*preferred-embed-gguf-names*
           #:*lmstudio-embed-models*
           #:lmstudio-embed-models
           #:split-csv
           #:parse-dotenv
           #:apply-dotenv
           #:find-dotenv
           #:find-and-apply-dotenv
           #:with-http-runtime
           #:make-lmstudio-backend
           #:run-lmstudio-embed-smoke
           #:run-vllm-embed-smoke
           #:run-usecase
           #:run-mock
           #:run-live
           #:make-vllm-backend))

(in-package #:cl-stack-llm-demo)
