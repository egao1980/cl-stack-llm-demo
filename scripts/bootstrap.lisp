;;;; This checkout + cl-repository-client. No workspace siblings.
;;;; Client from CL_REPOSITORY_CLIENT_DIR, ./.cl-repository, or ~/.local/share.

(defparameter *demo-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname
    (or *load-truename* *compile-file-truename* (uiop:getcwd)))))

(defun %env-dir (name)
  (let ((v (uiop:getenv name)))
    (when (and v (plusp (length v)))
      (let ((p (probe-file v)))
        (and p (uiop:ensure-directory-pathname p))))))

(defun %first-dir (pattern)
  (car (sort (directory pattern) #'string> :key #'namestring)))

(defun %client-dest ()
  (or (%env-dir "CL_REPOSITORY_DEST")
      (let ((p (merge-pathnames ".cl-repository/" *demo-root*)))
        (when (probe-file p) (uiop:ensure-directory-pathname p)))))

(defun %client-dir ()
  (or (%env-dir "CL_REPOSITORY_CLIENT_DIR")
      (let ((dest (%client-dest)))
        (when dest
          (or (%first-dir (merge-pathnames "cl-oci-*/" dest))
              (%first-dir (merge-pathnames "cl-repository-client-*/" dest)))))
      (%first-dir (merge-pathnames
                   ".local/share/cl-repository-client/cl-oci-*/"
                   (user-homedir-pathname)))))

(defun %bind-demo-asdf ()
  (let ((client (%client-dir))
        (dest (%client-dest))
        (repo (merge-pathnames ".local/share/cl-repository/systems/"
                               (user-homedir-pathname))))
    (unless client
      (error "cl-repository-client not found — run scripts/setup-client.sh"))
    (asdf:initialize-source-registry
     `(:source-registry
       (:directory ,*demo-root*)
       ,@(when dest `((:tree ,dest)))
       (:tree ,client)
       ,@(when (probe-file repo) `((:tree ,repo)))
       :ignore-inherited-configuration))
    (format t "~&; demo: root=~a~%;       client=~a~%" *demo-root* client)))

(%bind-demo-asdf)
(asdf:load-asd (merge-pathnames "cl-stack-llm-demo.asd" *demo-root*))
(asdf:load-system "cl-repository-client")
(cl-repository-client/asdf-integration:configure-asdf-source-registry)
(cl-repository-client/asdf-integration:load-system-init-files)
