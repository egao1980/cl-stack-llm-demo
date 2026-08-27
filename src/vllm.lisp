(in-package #:cl-stack-llm-demo)

(defun make-vllm-backend (&key model-path (max-model-len 2048) device)
  "Load a vllm.cpp engine. MAX-MODEL-LEN keeps Metal KV cache small."
  (let* ((path (or model-path (find-lmstudio-model)))
         (engine (vllm-cpp:load-engine
                  :model-path path
                  :device (or device (vllm-cpp:default-device))
                  :max-model-len max-model-len)))
    (llm-protocol-vllm-cpp:make-vllm-cpp-backend
     :model-path path
     :device (vllm-cpp:engine-device engine)
     :engine engine)))

(defun run-live (&key model-path (usecases *usecases*) (max-model-len 2048))
  "vllm.cpp + MCP sampling + agent. Needs libvllm + a GGUF."
  (unless (vllm-cpp:vllm-available-p)
    (error "libvllm not loaded — overlay or VLLM_CPP_NATIVE"))
  (let* ((path (or model-path (find-lmstudio-model)))
         (backend (make-vllm-backend :model-path path :max-model-len max-model-len)))
    (unless path
      (error "no GGUF — set VLLM_MODEL_PATH or install an LM Studio chat model"))
    (format t "~&live: model=~a device=~s~%"
            path (llm-protocol-vllm-cpp:vllm-cpp-device backend))
    (unwind-protect
         (let ((*host-client* (make-host-client :backend backend)))
           (multiple-value-bind (agent server client)
               (make-demo-stack :agent-backend backend :sample-backend backend)
             (declare (ignore client))
             (format t "~&-- smoke generate~%")
             (let ((r (llm-protocol:generate
                       backend
                       "Reply with the single word pong and nothing else."
                       :settings '(:temperature 0 :max-tokens 16))))
               (format t "~&generate: ~s~%" (llm-protocol:llm-response-text r))
               (unless (plusp (length (or (llm-protocol:llm-response-text r) "")))
                 (error "empty generate")))
             (format t "~&-- smoke MCP sampling~%")
             (let ((draft (%mcp-result-text
                           (call-draft-reply
                            server
                            :customer "Sam Lee"
                            :issue "late keyboard"
                            :facts (stack-json:encode (lookup-order "1001"))))))
               (format t "~&draft_reply: ~a~%" draft)
               (unless (plusp (length (string-trim '(#\Space #\Tab #\Newline) draft)))
                 (error "empty draft_reply")))
             (format t "~&-- agent usecases~%")
             (with-demo-loop
               (dolist (uc usecases)
                 (handler-case
                     (run-usecase agent uc :max-steps 6 :max-tokens 256)
                   (error (e)
                     (format t "~&usecase ~a FAIL: ~a~%" (getf uc :id) e)))))
             t))
      (llm-protocol-vllm-cpp:close-vllm-cpp-backend backend))))
