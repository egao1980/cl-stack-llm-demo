(defsystem "cl-stack-llm-demo"
  :version "0.1.0"
  :description "Canary: vllm.cpp llm-protocol + MCP sampling + ai-agent-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("alexandria"
               "llm-protocol"
               "ai-agent-protocol"
               "ai-agent-protocol/mcp"
               "mcp-protocol"
               "event-protocol"
               "event-backend-libuv"
               "json-protocol"
               "json-backend-jzon")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "fixture")
               (:file "models")
               (:file "mcp")
               (:file "agent"))
  :in-order-to ((test-op (test-op "cl-stack-llm-demo/tests"))))

(defsystem "cl-stack-llm-demo/openai"
  :version "0.1.0"
  :description "LM Studio OpenAI-compat HTTP backend for cl-stack-llm-demo"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cl-stack-llm-demo" "llm-protocol-openai" "http-backend-async"
               "event-backend-libuv")
  :serial t
  :pathname "src"
  :components ((:file "openai")))

(defsystem "cl-stack-llm-demo/vllm"
  :version "0.1.0"
  :description "Live vllm.cpp backend for cl-stack-llm-demo"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cl-stack-llm-demo" "llm-backend-vllm-cpp" "vllm-cpp")
  :serial t
  :pathname "src"
  :components ((:file "vllm")))

(defsystem "cl-stack-llm-demo/llama"
  :version "0.1.0"
  :description "Live llama.cpp backend for cl-stack-llm-demo"
  :author "egao1980"
  :license "MIT"
  :depends-on ("cl-stack-llm-demo" "llm-backend-llama-cpp" "llama-cpp")
  :serial t
  :pathname "src"
  :components ((:file "llama")))

(defsystem "cl-stack-llm-demo/tests"
  :depends-on ("cl-stack-llm-demo" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "demo-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
