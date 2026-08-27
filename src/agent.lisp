(in-package #:cl-stack-llm-demo)

(defmacro with-demo-loop (&body body)
  `(let* ((eb (event-backend-libuv:make-libuv-backend))
          (el (event-protocol:make-event-loop eb)))
     (event-protocol:with-event-backend (eb)
       (event-protocol:with-event-loop-var (el)
         ,@body))))

(defun lookup-order-handler (args)
  (let* ((obj (decode-args args))
         (id (or (%arg obj "order_id") (%arg obj "orderId") (%arg obj "id")))
         (row (lookup-order id)))
    (format t "~&   [CL] lookup_order ~a~%" id)
    (stack-json:encode row)))

(defun lookup-kb-handler (args)
  (let* ((obj (decode-args args))
         (topic (or (%arg obj "topic") (%arg obj "name") "password-reset"))
         (row (lookup-kb topic)))
    (format t "~&   [CL] lookup_kb ~a~%" topic)
    (stack-json:encode row)))

(defun make-desk-agent (&key backend tools)
  (let ((agent (ai-agent-protocol:make-ai-agent
                :name "desk"
                :backend backend
                :instructions *desk-instructions*)))
    (ai-agent-protocol:define-agent-tool
        agent "lookup_order"
        (:description "Look up a Northwind Gear order by id. Returns JSON facts."
         :parameters (mcp-protocol:json-object
                      "type" "object"
                      "properties"
                      (mcp-protocol:json-object
                       "order_id" (mcp-protocol:json-object
                                   "type" "string"
                                   "description" "Order id, e.g. 1001"))
                      "required" (vector "order_id")))
        (args)
      (lookup-order-handler args))
    (ai-agent-protocol:define-agent-tool
        agent "lookup_kb"
        (:description "Look up a support article (password-reset, returns)."
         :parameters (mcp-protocol:json-object
                      "type" "object"
                      "properties"
                      (mcp-protocol:json-object
                       "topic" (mcp-protocol:json-object "type" "string"))
                      "required" (vector "topic")))
        (args)
      (lookup-kb-handler args))
    (dolist (src tools)
      (ai-agent-protocol:register-agent-tool agent src))
    agent))

(defun on-event (kind payload)
  (case kind
    (:started
     (format t "~&== started agent=~s~%"
             (ai-agent-protocol:ai-agent-name
              (ai-agent-protocol:agent-run-agent payload))))
    (:step
     (format t "~&-- generate step ~a~%" payload))
    (:response
     (format t "~&   llm finish=~s text=~s calls=~s~%"
             (llm-protocol:llm-response-finish-reason payload)
             (llm-protocol:llm-response-text payload)
             (mapcar #'llm-protocol:llm-tool-call-part-name
                     (llm-protocol:llm-response-tool-calls payload))))
    (:finished
     (format t "~&== finished ~s~%"
             (ai-agent-protocol:agent-run-finish-reason payload)))
    (t
     (format t "~&   event ~s~%" kind))))

(defun run-usecase (agent usecase &key (max-steps 6) (max-tokens 256))
  (format t "~%~%######## ~a — ~a~%"
          (getf usecase :id) (getf usecase :title))
  (format t "user: ~a~%" (getf usecase :user))
  (let ((run (ai-agent-protocol:run-ai-agent
              agent (getf usecase :user)
              :settings (ai-agent-protocol:make-agent-settings
                         :llm (llm-protocol:make-llm-settings
                               :temperature 0 :max-tokens max-tokens)
                         :max-steps max-steps)
              :on-event #'on-event)))
    (format t "~&desk: ~a~%" (or (ai-agent-protocol:agent-run-text run) ""))
    (dolist (inv (ai-agent-protocol:agent-run-invocations run))
      (format t "~&  invocation ~s status=~s~%"
              (ai-agent-protocol:agent-invocation-name inv)
              (ai-agent-protocol:agent-invocation-status inv)))
    run))

(defun %tool-call (id name args)
  (llm-protocol:make-llm-tool-call-part :id id :name name :arguments args))

(defun make-scripted-backend (steps)
  "STEPS is a list of tool-call lists or a final string."
  (let ((i 0))
    (llm-protocol:make-mock-llm-backend
     :handler
     (lambda (backend turns &key &allow-other-keys)
       (declare (ignore backend turns))
       (let ((step (nth i steps)))
         (incf i)
         (cond
           ((null step)
            (llm-protocol:make-llm-response
             :parts (list (llm-protocol:make-llm-text-part :text "done"))
             :finish-reason :stop))
           ((stringp step)
            (llm-protocol:make-llm-response
             :parts (list (llm-protocol:make-llm-text-part :text step))
             :finish-reason :stop))
           (t
            (llm-protocol:make-llm-response
             :parts step
             :finish-reason :tool-use))))))))

(defun make-demo-stack (&key agent-backend sample-backend)
  (let* ((sample (or sample-backend agent-backend))
         (client (make-host-client :backend sample))
         (server (make-support-desk-server :host-client client))
         (src (make-instance 'desk-mcp-source :peer server))
         (agent (make-desk-agent :backend agent-backend :tools (list src))))
    (values agent server client)))

(defun run-mock (&key)
  "Offline canary: mock GENERATE + MCP sampling + agent tools."
  (let* ((sample-backend (llm-protocol:make-mock-llm-backend :prefix "DRAFT: "))
         (agent-backend
          (make-scripted-backend
           (list (list (%tool-call "c1" "lookup_order" "{\"order_id\":\"1001\"}"))
                 (list (%tool-call "c2" "draft_reply"
                                   "{\"customer\":\"Sam Lee\",\"issue\":\"late keyboard\",\"facts\":\"order 1001 in transit, new ETA Friday\"}"))
                 "Sam — the keyboard is on a carrier delay; Friday is the new ETA. Draft is below.")))
         (uc (first *usecases*)))
    (multiple-value-bind (agent server client)
        (make-demo-stack :agent-backend agent-backend :sample-backend sample-backend)
      (declare (ignore server))
      (let ((*host-client* client))
        (with-demo-loop
          (let ((run (run-usecase agent uc :max-steps 5 :max-tokens 64)))
            (unless (find "draft_reply" (ai-agent-protocol:agent-run-invocations run)
                          :key #'ai-agent-protocol:agent-invocation-name
                          :test #'equal)
              (error "mock agent never called draft_reply"))
            (unless (eq :stop (ai-agent-protocol:agent-run-finish-reason run))
              (error "expected finish :stop, got ~s"
                     (ai-agent-protocol:agent-run-finish-reason run)))
            run))))))

(defun make-vllm-backend (&key model-path)
  (error "load cl-stack-llm-demo/vllm for a live backend (model ~s)"
         model-path))
