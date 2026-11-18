;;;; Offline mock canary (no libvllm).
;;;;   cl-repo sync
;;;;   cl-repo run -- ros -l scripts/run-mock.lisp

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&MOCK FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-stack-llm-demo")
(cl-stack-llm-demo:run-mock)
(format t "~&MOCK OK~%")
(uiop:quit 0)
