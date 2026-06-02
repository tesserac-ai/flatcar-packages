;;; site-start.el --- Flatcar tools sysext defaults  -*- lexical-binding: t -*-

;; Loaded before user init. Flatcar ships no C toolchain, so native
;; compilation can't run; the core lisp is already AOT-compiled in the image.
;; Keep it off, including the trampolines Emacs would otherwise build on demand.
(setq native-comp-jit-compilation nil
      native-comp-enable-subr-trampolines nil)
