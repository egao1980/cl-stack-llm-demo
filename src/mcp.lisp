(in-package #:cl-stack-llm-demo)

;;; MCP server tool DRAFT_REPLY calls REQUEST-SAMPLING. The host binds
;;; *HOST-CLIENT* (sampling-handler → GENERATE) and resumes via PROVIDE-INPUT.
;;; Do not route this through mcp-client:call-tool — a handler that always
;;; samples would loop on the input_required retry.

(defvar *host-client* nil)
(defvar *max-sample-tokens* 160)

(defun %first-hash-value (table)
  (let ((out nil))
    (when (hash-table-p table)
      (maphash (lambda (k v)
                 (declare (ignore k))
                 (unless out (setf out v)))
               table))
    out))

(defun %sampling-text (raw)
  (cond
    ((stringp raw) raw)
    ((hash-table-p raw)
     (let ((c (or (gethash "content" raw) raw)))
       (cond
         ((stringp c) c)
         ((hash-table-p c) (or (gethash "text" c) (princ-to-string raw)))
         (t (princ-to-string raw)))))
    (t (princ-to-string raw))))

(defun sample-text (params)
  "REQUEST-SAMPLING → host CREATE-MESSAGE (GENERATE)."
  (%sampling-text
   (handler-bind ((mcp-protocol:mcp-input-required
                   (lambda (c)
                     (unless *host-client*
                       (error "no *host-client* — bind a sampling host"))
                     (mcp-protocol:invoke-provide-input
                      (or (%first-hash-value
                           (mcp-protocol:fulfill-input-requests
                            *host-client*
                            (mcp-protocol:mcp-input-required-requests c)))
                          (mcp-protocol:json-object))
                      c))))
     (mcp-protocol:request-sampling params))))

(defun draft-reply-handler (args)
  (let* ((obj (decode-args args))
         (customer (or (%arg obj "customer") "the customer"))
         (issue (or (%arg obj "issue") ""))
         (facts (or (%arg obj "facts") ""))
         (tone (or (%arg obj "tone") "warm and concise"))
         (prompt (format nil
                         "Customer: ~a~%Issue: ~a~%Facts (do not invent others): ~a~%~
Write a short support email (~a). 2-4 sentences. No subject line."
                         customer issue facts tone)))
    (format t "~&   [MCP] draft_reply sampling customer=~s~%" customer)
    (sample-text
     (mcp-protocol:json-object
      "systemPrompt"
      "You are a support writer for Northwind Gear. Use only the supplied facts. Do not invent order details, refunds, or dates. Sign as Alex from Support."
      "messages"
      (vector (mcp-protocol:json-object
               "role" "user"
               "content" (mcp-protocol:make-text-content prompt)))
      "maxTokens" *max-sample-tokens*
      "temperature" 0.2))))

(defclass desk-mcp-source (ai-agent-protocol/mcp:mcp-tool-source)
  ()
  (:documentation "Decode JSON-string tool args before MCP schema validation."))

(defmethod ai-agent-protocol:invoke-tool-async
    ((source desk-mcp-source) name arguments &key context callback error-callback)
  (call-next-method source name (decode-args arguments)
                    :context context :callback callback
                    :error-callback error-callback))

(defun make-support-desk-server (&key host-client)
  (let ((server (make-instance 'mcp-protocol:mcp-server
                               :name "support-desk"
                               :version "0.1.0"
                               :instructions
                               "Draft customer replies via host sampling/createMessage.")))
    (mcp-protocol:register-tool
     server
     (mcp-protocol:make-mcp-tool
      "draft_reply"
      :description "Draft a customer-support email from issue + verified facts. Uses host LLM sampling."
      :input-schema
      (mcp-protocol:json-object
       "type" "object"
       "properties"
       (mcp-protocol:json-object
        "customer" (mcp-protocol:json-object "type" "string"
                                             "description" "Customer name")
        "issue" (mcp-protocol:json-object "type" "string"
                                          "description" "What they wrote")
        "facts" (mcp-protocol:json-object "type" "string"
                                          "description" "Verified JSON/text facts only")
        "tone" (mcp-protocol:json-object "type" "string"))
       "required" (vector "issue" "facts"))
      :handler (lambda (args)
                 ;; Worker threads do not inherit *HOST-CLIENT*.
                 (let ((*host-client* (or host-client *host-client*)))
                   (draft-reply-handler args)))))
    server))

(defun make-host-client (&key backend)
  (make-instance 'mcp-protocol:mcp-client
                 :sampling-handler
                 (ai-agent-protocol/mcp:make-mcp-sampling-handler :backend backend)))

(defun call-draft-reply (server &key customer issue facts tone)
  (mcp-protocol:call-tool
   server "draft_reply"
   (mcp-protocol:json-object
    "customer" (or customer :omit)
    "issue" issue
    "facts" facts
    "tone" (or tone :omit))))

(defun %mcp-result-text (result)
  (cond
    ((stringp result) result)
    ((hash-table-p result)
     (let ((content (gethash "content" result)))
       (cond
         ((and (or (vectorp content) (listp content))
               (plusp (length content)))
          (or (gethash "text" (elt (coerce content 'vector) 0))
              (princ-to-string result)))
         (t (princ-to-string result)))))
    (t (princ-to-string result))))
