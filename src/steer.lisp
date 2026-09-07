(in-package #:cl-stack-llm-demo)

(defparameter *steer-demo-prompt*
  "I am adding a first-party protocol in this workspace. Which test runner do I use, and how do I declare dependencies?")

(defparameter *default-steer-skills*
  '("asdf" "rove" "common-lisp-workspace"))

(defun workspace-root ()
  "cl-workspace root (parent of this demo) when `.lisp-workspace/skills` exists."
  (or (let ((v (%env "CL_WORKSPACE")))
        (and v (uiop:directory-exists-p v)
             (uiop:ensure-directory-pathname v)))
      (let* ((demo (asdf:system-source-directory "cl-stack-llm-demo"))
             (parent (and demo (uiop:pathname-parent-directory-pathname demo))))
        (when (and parent
                   (uiop:directory-exists-p
                    (merge-pathnames ".lisp-workspace/skills/" parent)))
          parent))))

(defun demo-skill-root ()
  (merge-pathnames "skills/" (asdf:system-source-directory "cl-stack-llm-demo")))

(defun %steer-skill-names ()
  (or (split-csv (%env "STEER_SKILLS"))
      (copy-list *default-steer-skills*)))

(defun %steer-skill-roots ()
  (or (mapcar #'uiop:ensure-directory-pathname
              (split-csv (%env "STEER_SKILL_ROOTS")))
      (remove nil
              (list (demo-skill-root)
                    (let ((ws (workspace-root)))
                      (and ws (merge-pathnames ".lisp-workspace/skills/" ws)))))))

(defun %load-named-skills (root names)
  (loop for d in (steer-protocol:load-skills-from-directory root)
        when (or (null names)
                 (find (steer-protocol:steer-directive-name d) names
                       :test #'string-equal))
          collect d))

(defun make-workspace-rules ()
  (list (steer-protocol:make-steer-rule
         "cite-packages"
         :description "Name the Lisp package."
         :body "Always name the Common Lisp package (`steer-protocol`, `ai-agent-protocol`, `rove`). Never say \"the library\".")
        (steer-protocol:make-steer-rule
         "oci-pins"
         :description "Deps come from GHCR."
         :body "Never write `:sources ((\"foo\" :ql))`. First-party pins are `ghcr.io/egao1980/cl-systems`.")))

(defun %workspace-skill-root-p (root)
  (search ".lisp-workspace/skills" (namestring root)))

(defun make-workspace-steering (&key (roots (%steer-skill-roots))
                                  (names (%steer-skill-names)))
  "Rules + demo SKILL.md + selected workspace skills (not A2A agent-skill)."
  (let ((dirs (copy-list (make-workspace-rules))))
    (dolist (root roots)
      (when (uiop:directory-exists-p root)
        (setf dirs (append dirs
                           (%load-named-skills
                            root
                            (and (%workspace-skill-root-p root) names))))))
    (steer-protocol:make-in-memory-steering dirs)))

(defun %print-steering (src)
  (format t "~&-- steering ~a directive(s)~%"
          (length (steer-protocol:list-directives src)))
  (dolist (d (steer-protocol:list-directives src))
    (format t "   ~a ~a~@[  (~a)~]~%"
            (steer-protocol:steer-directive-kind d)
            (steer-protocol:steer-directive-name d)
            (let ((p (steer-protocol:steer-directive-path d)))
              (and p (namestring p)))))
  (let ((compiled (steer-protocol:compile-steering src)))
    (format t "~&-- compiled (~a chars)~%~a~%"
            (length compiled) compiled)
    compiled))

(defun make-steer-agent (&key backend steering)
  (ai-agent-protocol:make-ai-agent
   :name "workspace-steer"
   :backend backend
   :instructions "Answer in one short paragraph. Obey the steering block."
   :steering steering))

(defun run-steer-mock (&key (prompt *steer-demo-prompt*)
                         (steering (make-workspace-steering)))
  "No GGUF. Scripted reply; asserts steering landed on the system turn."
  (%print-steering steering)
  (let ((backend (llm-protocol:make-mock-llm-backend :prefix "STEER: ")))
    (with-demo-loop
      (let* ((agent (make-steer-agent :backend backend :steering steering))
             (run (ai-agent-protocol:run-ai-agent
                   agent prompt
                   :settings (ai-agent-protocol:make-agent-settings
                              :llm (llm-protocol:make-llm-settings
                                    :temperature 0 :max-tokens 64)
                              :max-steps 1)
                   :on-event #'on-event))
             (sys (find :system (ai-agent-protocol:agent-run-turns run)
                        :key #'llm-protocol:llm-turn-role)))
        (unless sys
          (error "steer mock: no system turn"))
        (unless (search "cite-packages" (llm-protocol:turn-text sys))
          (error "steer mock: cite-packages missing from system turn"))
        (format t "~&desk: ~a~%" (or (ai-agent-protocol:agent-run-text run) ""))
        run))))

(defun run-steer-llama (&key (prompt *steer-demo-prompt*)
                          model-path
                          (n-ctx (or (let ((v (%env "LLAMA_N_CTX")))
                                       (and v (parse-integer v :junk-allowed t)))
                                     2048))
                          (max-tokens 128)
                          (steering (make-workspace-steering)))
  "Live llama.cpp generate with workspace rules / SKILL.md."
  (asdf:load-system "cl-stack-llm-demo/llama")
  (unless (uiop:symbol-call :llama-cpp :llama-available-p)
    (error "libllamastack not available — build llama-cpp overlay or set LLAMA_CPP_NATIVE"))
  (let ((path (or model-path (find-llama-chat-model))))
    (unless path
      (error "no chat GGUF — set LLAMA_MODEL_PATH"))
    (%print-steering steering)
    (format t "~&-- llama chat path=~s n-ctx=~a~%" path n-ctx)
    (let ((b (uiop:symbol-call :cl-stack-llm-demo :make-llama-chat-backend
                               :model-path path :n-ctx n-ctx)))
      (unwind-protect
           (with-demo-loop
             (let* ((agent (make-steer-agent :backend b :steering steering))
                    (run (ai-agent-protocol:run-ai-agent
                          agent prompt
                          :settings (ai-agent-protocol:make-agent-settings
                                     :llm (uiop:symbol-call
                                           :llm-backend-llama-cpp :llama-cpp-settings
                                           :temperature 0
                                           :max-tokens max-tokens
                                           :chat-template :auto)
                                     :max-steps 1)
                          :on-event #'on-event)))
               (format t "~&desk: ~a~%" (or (ai-agent-protocol:agent-run-text run) ""))
               run))
        (uiop:symbol-call :llm-backend-llama-cpp :close-llama-cpp-backend b)))))
