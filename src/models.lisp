(in-package #:cl-stack-llm-demo)

(defun %env (name)
  (let ((v (uiop:getenv name)))
    (and v (plusp (length v)) v)))

(defun lmstudio-model-roots ()
  (remove-if-not
   #'uiop:directory-exists-p
   (list (namestring (merge-pathnames ".lmstudio/models/" (user-homedir-pathname)))
         (namestring (merge-pathnames "Library/Application Support/LM Studio/models/"
                                      (user-homedir-pathname))))))

(defparameter *preferred-gguf-names*
  '("NVIDIA-Nemotron-3-Nano-4B-Q4_K_M.gguf"
    "gemma-4-12B-it-Q4_K_M.gguf"))

(defun %skip-gguf-p (path)
  (let ((n (string-downcase (file-namestring path))))
    (or (search "embed" n)
        (search "mmproj" n)
        (search "ocr" n)
        (search "clip" n))))

(defun list-lmstudio-ggufs (&optional roots)
  (loop for root in (or roots (lmstudio-model-roots))
        append (let ((acc '()))
                 (uiop:collect-sub*directories
                  (uiop:ensure-directory-pathname root)
                  (constantly t) (constantly t)
                  (lambda (dir)
                    (dolist (p (directory (merge-pathnames "*.gguf" dir)))
                      (push p acc))))
                 acc)))

(defun %file-size (path)
  (ignore-errors
    (with-open-file (in path :element-type '(unsigned-byte 8))
      (file-length in))))

(defun find-lmstudio-model (&key (prefer *preferred-gguf-names*))
  "Smallest chat-capable LM Studio GGUF, unless VLLM_MODEL_PATH is set."
  (or (%env "VLLM_MODEL_PATH")
      (%env "VLLM_CPP_MODEL")
      (let ((files (remove-if #'%skip-gguf-p (list-lmstudio-ggufs))))
        (or (loop for name in prefer
                  for hit = (find name files :test #'string-equal :key #'file-namestring)
                  when hit return (namestring hit))
            (when files
              (namestring (first (sort (copy-list files) #'<
                                       :key (lambda (p) (or (%file-size p) most-positive-fixnum))))))))))
