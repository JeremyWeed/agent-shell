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
;; This file provides experimental TRAMP support for agent-shell,
;; allowing agents to run on remote hosts accessed via TRAMP.
;;
;; Enable with `agent-shell-enable-tramp-support' or:
;;
;;   (require 'agent-shell-tramp)
;;   (agent-shell-enable-tramp-support)
;;

;;; Code:

(declare-function agent-shell-cwd "agent-shell")
(defvar agent-shell-container-command-runner)
(defvar agent-shell-path-resolver-function)

(declare-function tramp-tramp-file-p "tramp")
(declare-function tramp-dissect-file-name "tramp")
(declare-function tramp-file-name-method "tramp")
(declare-function tramp-file-name-user "tramp")
(declare-function tramp-file-name-host "tramp")
(declare-function tramp-file-name-port "tramp")
(declare-function tramp-file-name-hop "tramp")
(declare-function tramp-file-name-localname "tramp")
(declare-function tramp-make-tramp-file-name "tramp")

(defun agent-shell--tramp-command-runner (buffer)
  "Return command prefix for running commands on TRAMP remote host.
BUFFER is the agent-shell buffer.
Returns nil for non-TRAMP buffers, allowing local execution."
  (require 'tramp)
  (with-current-buffer buffer
    (let ((cwd (agent-shell-cwd)))
      (when (tramp-tramp-file-p cwd)
        (let* ((vec (tramp-dissect-file-name cwd))
               (method (tramp-file-name-method vec))
               (user (tramp-file-name-user vec))
               (host (tramp-file-name-host vec))
               (port (tramp-file-name-port vec)))
          (unless (member method '("ssh" "scp" nil))
            (error "TRAMP method '%s' not supported; only SSH is supported" method))
          (when (tramp-file-name-hop vec)
            (error "Multi-hop TRAMP paths not supported"))
          (append
           (list "ssh")
           (when port (list "-p" port))
           (list (if user (format "%s@%s" user host) host))
           (list "--")))))))

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

;;;###autoload
(defun agent-shell-enable-tramp-support ()
  "Enable TRAMP support for agent-shell (experimental)."
  (interactive)
  (require 'agent-shell)
  (setq agent-shell-container-command-runner #'agent-shell--tramp-command-runner)
  (setq agent-shell-path-resolver-function #'agent-shell--resolve-tramp-path)
  (message "TRAMP support enabled for agent-shell"))

;;;###autoload
(defun agent-shell-disable-tramp-support ()
  "Disable TRAMP support for agent-shell."
  (interactive)
  (require 'agent-shell)
  (setq agent-shell-container-command-runner nil)
  (setq agent-shell-path-resolver-function nil)
  (message "TRAMP support disabled for agent-shell"))

(defun agent-shell--tramp-transcript-dir (cwd)
  "Return local transcript directory for TRAMP CWD.
Returns nil if CWD is not a TRAMP path."
  (when (and (fboundp 'tramp-tramp-file-p)
             (tramp-tramp-file-p cwd))
    (require 'tramp)
    (let* ((vec (tramp-dissect-file-name cwd))
           (host (tramp-file-name-host vec))
           (localname (tramp-file-name-localname vec))
           (safe-path (replace-regexp-in-string "/" "_" (string-trim localname "/"))))
      (expand-file-name (format ".agent-shell/transcripts/%s/%s" host safe-path)
                        (expand-file-name "~")))))

(provide 'agent-shell-tramp)
;;; agent-shell-tramp.el ends here
