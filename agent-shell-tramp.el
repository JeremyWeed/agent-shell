;;; agent-shell-tramp.el --- TRAMP support for agent-shell -*- lexical-binding: t; -*-

;; Copyright (C) 2024 Alvaro Ramirez

;; Author: Alvaro Ramirez https://xenodium.com
;; URL: https://github.com/xenodium/agent-shell

;; This package is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This package is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This file provides TRAMP support for agent-shell, allowing agents
;; to run on remote hosts accessed via TRAMP.
;;
;; TRAMP support works automatically when `default-directory' is a
;; TRAMP path (e.g., /ssh:host:/path).  The agent runs on the remote
;; host via Emacs' file-handler mechanism.
;;

;;; Code:

(declare-function agent-shell-cwd "agent-shell")

(declare-function tramp-tramp-file-p "tramp")
(declare-function tramp-dissect-file-name "tramp")
(declare-function tramp-file-name-host "tramp")
(declare-function tramp-file-name-localname "tramp")
(declare-function tramp-make-tramp-file-name "tramp")

(defun agent-shell--resolve-tramp-path (path)
  "Resolve PATH between TRAMP format and remote-local format.

For example:
- /ssh:host:/project/README.md => /project/README.md
- /project/README.md => /ssh:host:/project/README.md"
  (require 'tramp)
  (let* ((cwd (agent-shell-cwd))
         (tramp-vec (and (tramp-tramp-file-p cwd)
                         (tramp-dissect-file-name cwd))))
    (cond
     ;; Path is already a TRAMP path - strip the prefix for the agent
     ((tramp-tramp-file-p path)
      (tramp-file-name-localname (tramp-dissect-file-name path)))
     ;; Path is a remote-local path - add TRAMP prefix for Emacs
     (tramp-vec
      (tramp-make-tramp-file-name tramp-vec path))
     ;; Not in a TRAMP context
     (t path))))

(defun agent-shell--tramp-transcript-dir (cwd)
  "Return local transcript directory for TRAMP CWD.
Returns nil if CWD is not a TRAMP path."
  (when (and (fboundp 'tramp-tramp-file-p)
             (tramp-tramp-file-p cwd))
    (require 'tramp)
    (let* ((vec (tramp-dissect-file-name cwd))
           (host (tramp-file-name-host vec))
           (localname (tramp-file-name-localname vec))
           (safe-path (replace-regexp-in-string "/" "_" (string-trim localname "/" "/"))))
      (expand-file-name (format ".agent-shell/transcripts/%s/%s" host safe-path)
                        (expand-file-name "~")))))

(provide 'agent-shell-tramp)
;;; agent-shell-tramp.el ends here
