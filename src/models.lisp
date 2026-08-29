(in-package #:cl-stack-llm-demo)

(defun %env (name)
  (let ((v (uiop:getenv name)))
    (and v (plusp (length v)) v)))

(defun split-csv (s)
  "Comma-separated tokens. Does not split on colon (Unix paths)."
  (when (and s (plusp (length (string-trim '(#\Space #\Tab) s))))
    (loop for part in (uiop:split-string s :separator '(#\,))
          for trimmed = (string-trim '(#\Space #\Tab) part)
          when (plusp (length trimmed))
            collect trimmed)))

(defun %unquote-dotenv (s)
  (let ((n (length s)))
    (if (and (>= n 2)
             (or (and (char= (char s 0) #\") (char= (char s (1- n)) #\"))
                 (and (char= (char s 0) #\') (char= (char s (1- n)) #\'))))
        (subseq s 1 (1- n))
        s)))

(defun parse-dotenv (text)
  "Alist of (NAME . VALUE) from dotenv text."
  (let ((out '()))
    (dolist (raw (uiop:split-string (or text "") :separator '(#\Newline #\Return)))
      (let ((line (string-trim '(#\Space #\Tab) raw)))
        (when (and (plusp (length line)) (char/= (char line 0) #\#))
          (when (eql (search "export " line) 0)
            (setf line (string-trim '(#\Space #\Tab) (subseq line 7))))
          (let ((eqpos (position #\= line)))
            (when eqpos
              (let ((k (string-trim '(#\Space #\Tab) (subseq line 0 eqpos)))
                    (v (%unquote-dotenv
                        (string-trim '(#\Space #\Tab) (subseq line (1+ eqpos))))))
                (when (plusp (length k))
                  (push (cons k v) out))))))))
    (nreverse out)))

(defun apply-dotenv (path)
  "Set env from PATH. Does not override a non-empty existing value."
  (dolist (pair (parse-dotenv (uiop:read-file-string path)))
    (destructuring-bind (k . v) pair
      (unless (%env k)
        (setf (uiop:getenv k) v))))
  path)

(defun dotenv-candidates ()
  (let* ((explicit (%env "LLM_DEMO_ENV"))
         (sys (ignore-errors
                (uiop:ensure-directory-pathname
                 (asdf:system-source-directory "cl-stack-llm-demo"))))
         (cwd (uiop:getcwd)))
    (remove nil
            (list (and explicit (pathname explicit))
                  (merge-pathnames ".env" cwd)
                  (and sys (merge-pathnames ".env" sys))
                  (and sys (merge-pathnames ".env"
                                            (uiop:pathname-parent-directory-pathname sys)))))))

(defun find-dotenv ()
  (dolist (p (dotenv-candidates))
    (let ((found (probe-file p)))
      (when (and found (not (uiop:directory-pathname-p found)))
        (return found)))))

(defun find-and-apply-dotenv ()
  (let ((p (find-dotenv)))
    (when p
      (apply-dotenv p)
      p)))

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

(defparameter *preferred-embed-gguf-names*
  '("Qwen3-Embedding-0.6B-Q8_0.gguf"
    "bge-m3-Q8_0.gguf"))

(defparameter *lmstudio-embed-models*
  '("text-embedding-bge-m3"
    "text-embedding-qwen3-embedding-0.6b"))

(defun lmstudio-embed-models ()
  (or (split-csv (%env "LM_EMBED_MODELS"))
      (copy-list *lmstudio-embed-models*)))

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

(defun %assert-embed-result (r label)
  (unless (llm-protocol:llm-embed-result-p r)
    (error "not an llm-embed-result (~a): ~s" label r))
  (let ((embs (llm-protocol:llm-embed-result-embeddings r)))
    (unless embs
      (error "empty embeddings (~a)" label))
    (dolist (e embs)
      (let ((v (llm-protocol:llm-embedding-vector e)))
        (unless (and (vectorp v) (plusp (length v)))
          (error "empty embedding vector (~a)" label))
        (unless (every #'floatp v)
          (error "non-float embedding (~a)" label))))
    (values (length embs)
            (length (llm-protocol:llm-embedding-vector (first embs))))))

(defun find-lmstudio-embed-ggufs ()
  "Embed GGUFs for the vllm.cpp smoke. VLLM_EMBED_MODEL_PATH is a comma-separated override."
  (or (loop for raw in (or (split-csv (%env "VLLM_EMBED_MODEL_PATH")) '())
            for p = (probe-file raw)
            when p collect (namestring p))
      (let ((files (list-lmstudio-ggufs)))
        (loop for name in *preferred-embed-gguf-names*
              for hit = (find name files :test #'string-equal :key #'file-namestring)
              when hit collect (namestring hit)))))
