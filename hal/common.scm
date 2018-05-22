;; hal/common.scm --- common implementation    -*- coding: utf-8 -*-
;;
;; Copyright (C) 2018 Alex Sassmannshausen <alex@pompo.co>
;;
;; Author: Alex Sassmannshausen <alex@pompo.co>
;;
;; This file is part of guile-hal.
;;
;; guile-hal is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the Free
;; Software Foundation; either version 3 of the License, or (at your option)
;; any later version.
;;
;; guile-hal is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.
;;
;; You should have received a copy of the GNU General Public License along
;; with guile-hal; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 59 Temple Place - Suite 330        Fax:    +1-617-542-2652
;; Boston, MA  02111-1307,  USA       gnu@gnu.org

;;; Commentary:
;;
;;; Code:

(define-module (hal common)
  #:use-module (hal spec)
  #:use-module (hal builders)
  #:use-module (ice-9 match)
  #:use-module (ice-9 pretty-print)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:export (values->specification
            instantiate

            project-root-directory? find-project-root-directory

            read-spec

            guix-file

            base-autotools

            flatten))

(define (values->specification nam versio autho copyrigh synopsi descriptio
                               home-pag licens dependencie
                               lib-files tst-files prog-files doc-files
                               infra-files)
  (specification
   (name nam) (version versio) (author autho) (copyright copyrigh)
   (synopsis synopsi) (description descriptio) (home-page home-pag)
   (license licens) (dependencies dependencie)
   (all-files
    (files (append lib-files (base-libraries nam))
           (append tst-files (base-tests))
           (append prog-files (base-programs))
           (append doc-files (base-documentation nam))
           (append infra-files (base-infrastructure))))))

(define (instantiate spec context operation)
  (for-each (cute <> spec context operation "  ")
            (apply append
                   (map (cute <> (specification-files spec))
                        (list files-libraries files-tests files-programs
                              files-documentation files-infrastructure)))))

(define (project-root-directory?)
  (file-exists? "halcyon.scm"))

(define (find-project-root-directory)
  (let ((start (getcwd)))
    (let lp ((cwd (getcwd)))
      (cond ((project-root-directory?) `(,cwd))
            ((string=? cwd "/")
             (throw 'hal-find-project-root-directory
                    "No halcyon.scm file found.  Search started at:" start))
            (else
             (chdir "..")
             (lp (getcwd)))))))

(define (read-spec)
  (find-project-root-directory)
  (scm->specification
   (with-input-from-file "halcyon.scm"
     (lambda _ (read)))))

;;;; Defaults

(define (base-libraries name)
  `(,(file name 'scheme "scm" "")
    ,(directory name '())))

(define (base-tests)
  `(,(directory "tests" '())))

(define (base-programs)
  `(,(directory "bin" `())))

(define (base-documentation name)
  `(,(file "README" 'txt #f "")
    ,(file "HACKING" 'txt #f "")
    ,(file "COPYING" 'txt #f "")
    ,(directory "doc"
                `(,(file name 'texi "texi" "")))))

(define (base-infrastructure)
  `(,(guix-file)
    ,(file "halcyon" 'scheme "scm" #f)))

(define (base-autotools)
  `(,(configure-file)
    ,(makefile-file)
    ,(file "NEWS" 'txt #f "")
    ,(file "AUTHORS" 'txt #f "")
    ,(file "ChangeLog" 'txt #f "")
    ,(file "test-env" 'in "in"
           "
#!/bin/sh

\"@abs_top_builddir@/pre-inst-env\" \"$@\"

exit $?
")
    ,(file "pre-inst-env" 'in "in"
           "
#!/bin/sh

abs_top_srcdir=\"`cd \"@abs_top_srcdir@\" > /dev/null; pwd`\"
abs_top_builddir=\"`cd \"@abs_top_builddir@\" > /dev/null; pwd`\"

GUILE_LOAD_COMPILED_PATH=\"$abs_top_builddir${GUILE_LOAD_COMPILED_PATH:+:}$GUILE_LOAD_COMPILED_PATH\"
GUILE_LOAD_PATH=\"$abs_top_builddir:$abs_top_srcdir${GUILE_LOAD_PATH:+:}:$GUILE_LOAD_PATH\"
export GUILE_LOAD_COMPILED_PATH GUILE_LOAD_PATH

PATH=\"$abs_top_builddir/scripts:$PATH\"
export PATH

exec \"$@\"
")))

;;;;; Files

(define (configure-file)
  (file "configure" 'autoconf "ac"
        (lambda (spec)
          (display
           (string-append "
dnl -*- Autoconf -*-

AC_INIT(" (specification-name spec) ", " (specification-version spec) ")
AC_CONFIG_SRCDIR(" (match (find (match-lambda (('directory . rest) #t) (_ #f))
                                (map (cut <> '() '() 'write "")
                                     (files-libraries
                                      (specification-files spec))))
                     (('directory name children) name)) ")
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([1.12 gnu silent-rules subdir-objects \
 color-tests parallel-tests -Woverride -Wno-portability])
AM_SILENT_RULES([yes])

AC_CONFIG_FILES([Makefile])
AC_CONFIG_FILES([pre-inst-env], [chmod +x pre-inst-env])
AC_CONFIG_FILES([test-env], [chmod +x test-env])

dnl Search for 'guile' and 'guild'.  This macro defines
dnl 'GUILE_EFFECTIVE_VERSION'.
GUILE_PKG([2.0 2.2])
GUILE_PROGS
GUILE_SITE_DIR
if test \"x$GUILD\" = \"x\"; then
   AC_MSG_ERROR(['guild' binary not found; please check your guile-2.x installation.])
fi

AC_SUBST([guilesitedir])

AC_OUTPUT
          ")))))

(define (makefile-file)
  (file
   "Makefile" 'automake "am"
   (lambda (spec)
     (display
      (string-append "
GOBJECTS = $(SOURCES:%.scm=%.go)

moddir=$(guilesitedir)
godir=$(libdir)/guile/$(GUILE_EFFECTIVE_VERSION)/site-ccache
ccachedir=$(libdir)/guile/$(GUILE_EFFECTIVE_VERSION)/site-ccache

nobase_mod_DATA = $(SOURCES) $(NOCOMP_SOURCES)
nobase_go_DATA = $(GOBJECTS)

# Make sure source files are installed first, so that the mtime of
# installed compiled files is greater than that of installed source
# files.  See
# <http://lists.gnu.org/archive/html/guile-devel/2010-07/msg00125.html>
# for details.
guile_install_go_files = install-nobase_goDATA
$(guile_install_go_files): install-nobase_modDATA

EXTRA_DIST = $(SOURCES) $(NOCOMP_SOURCES)
GUILE_WARNINGS = -Wunbound-variable -Warity-mismatch -Wformat
SUFFIXES = .scm .go
.scm.go:
	$(AM_V_GEN)$(top_builddir)/pre-inst-env $(GUILE_TOOLS) compile $(GUILE_WARNINGS) -o \"$@\" \"$<\"

SOURCES = " (string-join
             (flatten (map (cute <> spec '() 'raw "")
                           (files-libraries (specification-files spec))))
             " \\\n") "

TESTS = " (string-join
           (flatten (map (cute <> spec '() 'raw "")
                         (files-tests (specification-files spec))))
           " \\\n") "

TEST_EXTENSIONS = .scm
AM_TESTS_ENVIRONMENT = abs_top_srcdir=\"$(abs_top_srcdir)\"
SCM_LOG_COMPILER = $(top_builddir)/test-env $(GUILE)
AM_SCM_LOG_FLAGS = --no-auto-compile -L \"$(top_srcdir)\"

info_TEXINFOS = " (string-join
                   (filter (cut string-match ".*\\.texi$" <>)
                           (flatten
                            (map (cute <> spec '() 'raw "")
                                 (files-documentation
                                  (specification-files spec)))))
                   " \\\n") "
dvi: # Don't build dvi docs

EXTRA_DIST += " (string-join
                 (filter (negate (cut string-match ".*\\.texi$" <>))
                         (flatten
                          (map (cute <> spec '() 'raw "")
                               (files-documentation
                                (specification-files spec)))))
                 " \\\n") " \\
  # pre-inst-env.in				\\
  # test-env.in					\\
  $(TESTS)

ACLOCAL_AMFLAGS = -I m4

clean-go:
	-$(RM) $(GOBJECTS)
.PHONY: clean-go

CLEANFILES =					\\
  $(GOBJECTS)					\\
  $(TESTS:tests/%.scm=%.log)
")))))

(define (guix-file)
  (file
   "guix" 'scheme "scm"
   (lambda (spec)
     (for-each (lambda (n) (pretty-print n) (newline))
               (list
                '(use-modules (guix packages)
                              (guix licenses)
                              (guix download)
                              (guix build-system gnu)
                              (gnu packages)
                              (gnu packages autotools)
                              (gnu packages guile)
                              (gnu packages pkg-config)
                              (gnu packages texinfo))
                `(package
                  (name ,(specification-name spec))
                  (version ,(specification-version spec))
                  (source ,(string-append "./" (specification-name spec) "-"
                                          (specification-version spec)
                                          ".tar.gz"))
                  (build-system gnu-build-system)
                  (native-inputs
                   `(("autoconf" ,autoconf)
                     ("automake" ,automake)
                     ("pkg-config" ,pkg-config)
                     ("texinfo" ,texinfo)))
                  (inputs `(("guile" ,guile-2.2)))
                  (propagated-inputs ,(specification-dependencies spec))
                  (synopsis ,(specification-synopsis spec))
                  (description ,(specification-description spec))
                  (home-page ,(specification-home-page spec))
                  (license ,(specification-license spec))))))))

;;;;; Validators

(define (name project-name)
  (or (and (string? project-name) project-name)
      (throw 'hal-spec-name "PROJECT-NAME should be a string."
             project-name)))

(define (version project-version)
  (or (and (string? project-version) project-version)
      (throw 'hal-spec-version "PROJECT-VERSION should be a string."
             project-version)))

(define (author project-author)
  (or (and (string? project-author) project-author)
      (throw 'hal-spec-author "PROJECT-AUTHOR should be a string."
             project-author)))

(define (synopsis project-synopsis)
  (or (and (string? project-synopsis) project-synopsis)
      (throw 'hal-spec-synopsis "PROJECT-SYNOPSIS should be a string."
             project-synopsis)))

(define (description project-description)
  (or (and (string? project-description) project-description)
      (throw 'hal-spec-description
             "PROJECT-DESCRIPTION should be a string."
             project-description)))

(define (home-page project-home-page)
  (or (and (string? project-home-page) project-home-page)
      (throw 'hal-spec-home-page "PROJECT-HOME-PAGE should be a string."
             project-home-page)))

;; FIXME: LICENSE should be a license object
(define (license project-license)
  (or (and (symbol? project-license) project-license)
      (throw 'hal-spec-license "PROJECT-LICENSE should be a string."
             project-license)))

(define (copyright project-copyrights)
  (match project-copyrights
    (((? number?) ...) project-copyrights)
    (_ (throw 'hal-spec-copyrights
              "PROJECT-COPYRIGHTs should be one or more numbers."
              project-copyrights))))

(define (dependencies project-dependencies)
  (match project-dependencies
    ((or ('quasiquote (()))
         ('quasiquote (((? string?) ('unquote (? symbol?))) ...)))
     project-dependencies)
    (_
     (throw 'hal-spec-dependencies
            "PROJECT-DEPENDENCIES should be one or more Guix style dependencies."
            project-dependencies))))

(define (all-files files) files)

;;;; Utilities

(define (flatten files)
  (match files
    (() '())
    (((? list? first) . rest)
     (append (flatten first) (flatten rest)))
    ((first . rest)
     (cons first (flatten rest)))))
