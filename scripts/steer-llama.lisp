;;;; Workspace llama.cpp + steer-protocol demo.
;;;; Does NOT use bootstrap.lisp (that ignores inherited ASDF).
;;;;
;;;;   cd /path/to/cl-workspace
;;;;   CL_SOURCE_REGISTRY="$PWD//:" ros -l cl-stack-llm-demo/scripts/steer-llama.lisp
;;;;
;;;; Mock (no GGUF):
;;;;   STEER_MOCK=1 CL_SOURCE_REGISTRY="$PWD//:" ros -l cl-stack-llm-demo/scripts/steer-llama.lisp
;;;;
;;;; Env: LLAMA_MODEL_PATH  LLAMA_N_CTX  STEER_SKILLS  STEER_SKILL_ROOTS  CL_WORKSPACE

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&STEER DEMO FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-stack-llm-demo")

(in-package #:cl-user)

(let ((env (cl-stack-llm-demo:find-and-apply-dotenv)))
  (when env
    (format t "~&dotenv=~s~%" (namestring env))))

(format t "~&workspace=~s skills=~s~%"
        (cl-stack-llm-demo:workspace-root)
        (cl-stack-llm-demo:demo-skill-root))

(if (and (uiop:getenv "STEER_MOCK")
         (plusp (length (uiop:getenv "STEER_MOCK")))
         (not (member (string-downcase (uiop:getenv "STEER_MOCK"))
                      '("0" "false" "no") :test #'string=)))
    (cl-stack-llm-demo:run-steer-mock)
    (cl-stack-llm-demo:run-steer-llama))

(format t "~&STEER DEMO OK~%")
(uiop:quit 0)
