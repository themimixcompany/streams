;;;; unparser.lisp

(uiop:define-package #:streams/unparser
  (:use #:cl
        #:streams/specials
        #:streams/classes)
  (:export #:metadatap
           #:datatype-format-p
           #:prefixedp
           #:flatten-1
           #:wrap
           #:join
           #:stage
           #:normalize
           #:combine
           #:compose
           #:construct
           #:collect))

(in-package #:streams/unparser)

(defun table-keys (table)
  "Return the direct keys under TABLE."
  (when (hash-table-p table)
    (loop :for k :being :the :hash-key :in table :collect k)))

(defun table-values (table)
  "Return the direct values under TABLE."
  (when (hash-table-p table)
    (loop :for v :being :the :hash-value :in table :collect v)))

(defun children (table &optional object)
  "Return all items in TABLE using KEY that are also tables."
  (when (hash-table-p table)
    (let ((keys (table-keys table)))
      (loop :for key :in keys
            :for value = (gethash key table)
            :when (hash-table-p value)
            :collect (if object value key)))))

(defun metadatap (value)
  "Return true if VALUE is the : namespace."
  (when (consp value)
    (let ((value (car value)))
      (and (stringp value)
           (string= value ":")))))

(defun datatype-format-p (value)
  "Return true if VALUE is a datatype or format form."
  (when (consp value)
    (let ((value (car value)))
      (and (stringp value)
           (or (string= value "d")
               (string= value "f"))))))

(defun prefixedp (value)
  "Return true if VALUE is prefixed by certain namespaces."
  (marie:when*
    (consp value)
    (member (car value) '(":" "d" "f") :test #'equal)))

(defun flatten-1 (list)
  "Return a flattened list on one level from LIST."
  (let ((value (mapcar #'(lambda (item)
                           (if (consp item) item (list item)))
                       list)))
    (reduce #'(lambda (x y)
                (cond ((prefixedp y) (append x (list y)))
                      (t (append x y))))
            value)))

(defun wrap (list)
  "Return a new list where items in LIST are conditionally listified."
  (mapcar #'(lambda (item)
              (cond ((or (atom item)
                         (and (consp item)
                              (not (prefixedp item))
                              (not (stringp (car item)))))
                     (list item))
                    ((metadatap item)
                     (cons (marie:cat (first item) (second item))
                           (cddr item)))
                    (t item)))
          list))

(defun join (list)
  "Return a new list where items in LIST are flattened to one level."
  (reduce #'(lambda (x y)
              (cond ((datatype-format-p y) (append x (list y)))
                    ((datatype-format-p x) (append (list x) y))
                    (t (append x y))))
          list))

(defun stage (list)
  "Return a new list from LIST where the items preprocessed for wrapping and joining."
  (labels ((fn (args acc)
             (cond ((null args) (nreverse acc))
                   ((datatype-format-p (car args))
                    (fn (cdr args)
                        (cons (flatten-1 (car args)) acc)))
                   ((metadatap (car args))
                    (fn (cdr args)
                        (cons (join (wrap (fn (car args) nil)))
                              acc)))
                   (t (fn (cdr args)
                          (cons (car args) acc))))))
    (fn list nil)))

(defun normalize (list)
  "Return special merging on items of LIST."
  (labels ((fn (val)
             (cond ((metadatap val) (cons (car val) (cadr val)))
                   (t val))))
    (join (wrap (stage (mapcar #'(lambda (item)
                                   (cond ((consp item) (fn item))
                                         (t item)))
                               list))))))

(defun %combine (list)
  "Return the list (X Y ...) from (X (Y ...)) from LIST."
  (labels ((fn (val)
             (cond ((prefixedp val)
                    (cons (car val) (cadr val)))
                   (t val))))
    (fn list)))

(defun combine (items)
  "Apply COMBINE on ITEMS."
  (mapcar #'%combine items))

(defun compose (items)
  "Apply additional merging operations to items in LIST."
  (labels ((fn (args acc)
             (cond ((null args) (nreverse acc))
                   ((metadatap (car args))
                    (fn (cdr args)
                        (cons (list (caar args)
                                    (combine (cadr (car args))))
                              acc)))
                   (t (fn (cdr args)
                          (cons (%combine (car args))
                                acc))))))
    (fn items nil)))

(defun accumulate (value acc)
  "Return an an accumulator value suitable for CONSTRUCT."
  (destructuring-bind (v &optional &rest vs)
      value
    (declare (ignorable vs))
    (cond ((string= "=" v) acc)
          (t (cons v acc)))))

(defun construct (key table)
  "Return the original expressions in TABLE under KEY."
  (labels ((fn (tab keys acc)
             (let ((v (gethash (car keys) tab)))
               (cond ((null keys) (nreverse acc))
                     ((hash-table-p v)
                      (fn tab
                          (cdr keys)
                          (cons (fn v
                                    (table-keys v)
                                    (list (car keys)))
                                acc)))
                     (t (fn tab
                            (cdr keys)
                            (cons v (accumulate keys acc))))))))
    (marie:when-let ((ht (gethash key table)))
      (loop :for v :in (fn ht (table-keys ht) nil)
            :for kv = (cons key v)
            :collect (normalize (compose kv))))))

(defun collect (&optional (table (atom-table *universe*)))
  "Return the original expressions in TABLE."
  (let ((keys (children table)))
    (loop :for key :in keys :nconc (construct key table))))
