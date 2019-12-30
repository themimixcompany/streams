;;;; streams.asd

#-ASDF3.1 (error "ASDF 3.1 or bust!")

(defpackage #:streams-system
  (:use #:cl #:asdf))

(in-package #:streams-system)

(defsystem #:streams
  :description "streams"
  :author "The Mimix Company <code@mimix.io>"
  :license "BlueOak-1.0.0"
  :version "1.1.0"
  :class :package-inferred-system
  :depends-on (#:cl-ppcre
               #:mof
               #:clack
               #:clack-handler-hunchentoot
               #:websocket-driver
               #:alexandria
               #:bordeaux-threads
               "streams/utils"
               "streams/globals"
               "streams/core"
               "streams/serve"
               "streams/msl"
               "streams/build"
               "streams/initialize"))
