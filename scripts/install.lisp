;;;; Install .asd deps from ghcr.io/egao1980/cl-systems.
;;;;   ./scripts/setup-client.sh
;;;;   ros -l scripts/install.lisp

(load (merge-pathnames "bootstrap.lisp" *load-truename*))

(setf *debugger-hook*
      (lambda (c h)
        (declare (ignore h))
        (format *error-output* "~&INSTALL FAIL: ~A~%" c)
        (uiop:print-backtrace :condition c :stream *error-output*)
        (uiop:quit 1)))

(asdf:load-system "cl-repository-client")
(cl-repo:add-registry "https://ghcr.io" :namespace "egao1980/cl-systems" :priority :prepend)

(defun %install (name &key (also-tests t))
  (format t "~&; install deps for ~a~%" name)
  (cl-repo:ensure-system-dependencies name
                                      :also-tests also-tests
                                      :default-source :oci)
  (cl-repository-client/asdf-integration:configure-asdf-source-registry))

(%install "cl-stack-llm-demo" :also-tests t)
(%install "cl-stack-llm-demo/vllm" :also-tests nil)
(cl-repository-client/asdf-integration:load-system-init-files)
(format t "~&; install done~%")
(uiop:quit 0)
