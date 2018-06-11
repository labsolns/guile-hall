;; hall/guix.scm --- guix implementation    -*- coding: utf-8 -*-
;;
;; Copyright (C) 2018 Alex Sassmannshausen <alex@pompo.co>
;;
;; Author: Alex Sassmannshausen <alex@pompo.co>
;;
;; This file is part of guile-hall.
;;
;; guile-hall is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 3 of the License, or (at your option)
;; any later version.
;;
;; guile-hall is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.
;;
;; You should have received a copy of the GNU General Public License along
;; with guile-hall; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 59 Temple Place - Suite 330        Fax:    +1-617-542-2652
;; Boston, MA  02111-1307,  USA       gnu@gnu.org

;;; Commentary:
;;
;;; Code:

(define-module (hall guix)
  #:use-module (hall common)
  #:use-module (hall spec)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (rewrite-guix-file git-guix-recipe tarball-guix-recipe))

(define (rewrite-guix-file spec context operation)
  (match operation
    ('exec ((guix-file) spec context operation ""))
    ((or 'show _)
     (format #t "Dryrun:~%")
     ((guix-file) spec context 'show-contents "")
     (format #t "Finished dryrun.~%"))))

(define (git-guix-recipe spec context operation)
  (match operation
    ('exec ((guix-file 'git) spec context 'show-contents ""))
    ((or 'show _)
     (format #t "Dryrun:~%")
     ((guix-file 'git) spec context 'show-contents "")
     (format #t "Finished dryrun.~%"))))

(define (tarball-guix-recipe spec context operation)
  (match operation
    ('exec ((guix-file 'tarball) spec context 'show-contents ""))
    ((or 'show _)
     (format #t "Dryrun:~%")
     ((guix-file 'tarball) spec context 'show-contents "")
     (format #t "Finished dryrun.~%"))))