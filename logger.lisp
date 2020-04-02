;;;; logger.lisp

(uiop:define-package #:streams/logger
  (:use #:cl
        #:streams/specials
        #:streams/classes)
  (:export #:*machine-name*
           #:*maximum-file-size*
           #:log-value))

(in-package #:streams/logger)

(marie:define-constant* +base-directory+
    (marie:home (marie:cat "." +self+ "/"))
  "The path to the default configuration and storage directory.")

(marie:define-constant* +default-log-file+
    (flet ((fn (parent path)
             (uiop:merge-pathnames* parent path)))
      (fn +base-directory+ (fn +self+ ".log")))
  "The path to the default file for logging.")

(marie:define-constant* +log-file-suffix+
  ".msl"
  "The default file suffix for log files.")

(defparameter *maximum-file-size*
  5242880
  "The maximum filesize of logging files in bytes.")

(defvar *machine-name*
  "my-machine"
  "The default name to use as the machine name.")

(marie:define-constant* +day-names+
    '("Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday" "Sunday")
  "The enumeration of week day names.")

(defun current-date ()
  "Return the current date and time in ISO 8601 format."
  (local-time:format-timestring nil (local-time:now)))

(marie:define-constant* +default-date+
    (current-date)
  "The default date and time string used for logging.")

(defun file-size (path)
  "Return the size of file indicated in PATH."
  (trivial-file-size:file-size-in-octets path))

(defun maximum-file-size-p (path)
  "Return true if the file indicated in PATH exceeds the maximum allowable size."
  (when (uiop:file-exists-p path)
    (> (file-size path) *maximum-file-size*)))

(defun build-path (path)
  "Return a new path based from the base directory."
  (uiop:merge-pathnames* +base-directory+ path))

(defun make-log-file-path (path)
  "Return a log file pathname from PATH."
  (build-path (marie:cat path +log-file-suffix+)))

(defun log-file-exists-p (name)
  "Return true if the log file indicated by PATH exists under the log directory."
  (let ((path (make-log-file-path name)))
    (uiop:file-exists-p path)))

(defun create-empty-file (path)
  "Create an empty file from PATH."
  (with-open-file (stream path :if-does-not-exist :create)))

(defun ensure-file-exists (path)
  "Create the log file indicated by PATH if it does not exist yet."
  (unless (uiop:file-exists-p path)
    (ensure-directories-exist path)
    (create-empty-file path)))

(defun purge-file (path)
  "Zero-out the file indicated by PATH."
  (uiop:delete-file-if-exists path)
  (create-empty-file path))

(defun purge-file* (path)
  "Zero-out the file indicated by PATH if it exceeds the threshold."
  (when (maximum-file-size-p path)
    (purge-file path)))

(defun make-machine-log-path (machine &optional (date +default-date+))
  "Return a log file path using MACHINE. Optional parameter DATE is for
specifying another date value."
  (make-log-file-path (marie:cat machine "." date)))

(defun update-log-date (mx-universe)
  "Update the log date on MX-UNIVERSE to the current one."
  (setf (log-date mx-universe)
        (local-time:format-timestring nil (local-time:now))))

(defun log-file (&optional update)
  "Return the current log file of the universe."
  (when update
    (update-log-date *mx-universe*))
  (make-machine-log-path *machine-name* (log-date *mx-universe*)))

(defun log-value (value)
  "Write VALUE to the computed log file."
  (flet ((fn (path)
           (ensure-file-exists path)
           (with-open-file (stream path :direction :output :if-exists :append)
             (format stream "~A~%" value))))
    (when (stringp value)
      (cond ((maximum-file-size-p (log-file))
             (fn (log-file t)))
            (t (fn (log-file)))))))
