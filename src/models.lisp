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

;;; Published darwin libvllm (vllm-cpp 0.1.1) only loads these GGUF families.
(defparameter *vllm-gguf-architectures*
  '("qwen35moe" "qwen3next" "qwen35" "deepseek4" "muse-glimmer"))

(defparameter *preferred-gguf-names*
  '("Qwen3.5-2B-Q4_K_M.gguf"
    "Qwen3.5-2B-Q4_0.gguf"
    "Qwen3.5-0.8B-Q4_K_M.gguf"
    "Qwen3.5-0.8B-Q4_0.gguf"))

(defun %ascii-octets (s)
  (map '(vector (unsigned-byte 8)) #'char-code s))

(defun gguf-architecture (path)
  "Best-effort scan of the GGUF header for a known architecture token."
  (ignore-errors
    (with-open-file (in path :element-type '(unsigned-byte 8))
      (let* ((n (min 131072 (or (file-length in) 0)))
             (buf (make-array n :element-type '(unsigned-byte 8))))
        (read-sequence buf in)
        (loop for arch in *vllm-gguf-architectures*
              when (search (%ascii-octets arch) buf)
                return arch)))))

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
  "LM Studio GGUF this libvllm can load, unless VLLM_MODEL_PATH is set.
   Overlay 0.1.1 only speaks qwen35 / qwen3next / deepseek4 / muse-glimmer."
  (or (%env "VLLM_MODEL_PATH")
      (%env "VLLM_CPP_MODEL")
      (let* ((files (remove-if #'%skip-gguf-p (list-lmstudio-ggufs)))
             (compat (remove-if-not #'gguf-architecture files)))
        (or (loop for name in prefer
                  for hit = (find name compat :test #'string-equal :key #'file-namestring)
                  when hit return (namestring hit))
            (when compat
              (namestring (first (sort (copy-list compat) #'<
                                       :key (lambda (p) (or (%file-size p) most-positive-fixnum))))))))))
