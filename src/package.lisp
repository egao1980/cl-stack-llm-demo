(defpackage #:cl-stack-llm-demo
  (:use #:cl)
  (:nicknames #:stack-llm-demo)
  (:export #:*host-client*
           #:*max-sample-tokens*
           #:*usecases*
           #:decode-args
           #:lookup-order
           #:lookup-kb
           #:make-support-desk-server
           #:make-host-client
           #:sample-text
           #:call-draft-reply
           #:make-desk-agent
           #:with-demo-loop
           #:find-lmstudio-model
           #:list-lmstudio-ggufs
           #:run-usecase
           #:run-mock
           #:run-live
           #:make-vllm-backend))

(in-package #:cl-stack-llm-demo)
