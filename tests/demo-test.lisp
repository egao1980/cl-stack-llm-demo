(in-package #:cl-stack-llm-demo/tests)

(deftest salvage-truncated-json
  (let ((obj (decode-args "{\"customer\":\"Sam\",\"issue\":\"late\",\"facts\":")))
    (ok (equal "Sam" (mcp-protocol:param obj "customer")))
    (ok (equal "late" (mcp-protocol:param obj "issue")))))

(deftest fixture-orders
  (ok (equal "Sam Lee" (mcp-protocol:param (lookup-order "1001") "customer")))
  (ok (equal "unknown order" (mcp-protocol:param (lookup-order "9999") "error")))
  (ok (equal "password-reset" (mcp-protocol:param (lookup-kb "password-reset") "topic")))
  (ok (equal "password-reset" (mcp-protocol:param (lookup-kb "password reset") "topic"))))

(deftest mcp-sampling-draft
  (let* ((sample (make-mock-llm-backend :prefix "DRAFT: "))
         (client (make-host-client :backend sample))
         (server (make-support-desk-server :host-client client))
         (out (call-draft-reply server
                                :customer "Sam"
                                :issue "late keyboard"
                                :facts "ETA Friday")))
    (ok (search "DRAFT:" (%mcp-result-text-for-test out)))))

(defun %mcp-result-text-for-test (result)
  (cl-stack-llm-demo::%mcp-result-text result))

(deftest agent-calls-sampling-tool
  (let ((run (run-mock)))
    (ok (eq :stop (agent-run-finish-reason run)))
    (ok (find "lookup_order" (agent-run-invocations run)
              :key #'agent-invocation-name :test #'equal))
    (ok (find "draft_reply" (agent-run-invocations run)
              :key #'agent-invocation-name :test #'equal))
    (let ((draft (find "draft_reply" (agent-run-invocations run)
                       :key #'agent-invocation-name :test #'equal)))
      (ok (eq :done (agent-invocation-status draft)))
      (ok (search "DRAFT:" (agent-invocation-result draft))))))

(deftest lmstudio-discovery
  (let ((path (find-lmstudio-model)))
    (if path
        (ok (or (probe-file path)
                (uiop:file-exists-p path)))
        (skip "no LM Studio GGUF on this machine"))))
