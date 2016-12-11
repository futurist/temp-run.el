;;; temp-execute.el --- Create temporary file from region or buffer, send it to execute using shell command. -*- lexical-binding: t; -*-

;; Filename: temp-execute.el
;; Description: Create temporary file from region or buffer, send it to execute using shell command, popup output result and easily dismissed.
;; Author: James Yang <jamesyang999@gmail.com>
;; Copyright (C) 2016, James Yang, all rights reserved.
;; Time-stamp: <2016-12-09 17:37:51 James Yang>
;; Created: 2016-12-09 17:37:51
;; Version: 0.1.0
;; URL: http://github.com/futurist/temp-execute.el
;; Keywords: temp, tempfile, execute, send-to
;; Package-Requires: ((emacs "24.1"))
;;

;;; This file is NOT part of GNU Emacs

;;; Commentary:

;; Create temporary file from region or buffer, send it to execute
;; using shell command.  Temp file will be write to
;; `temp-execute-default-dir' if USE-DEFAULT-DIR is non-nil or no
;; buffer file, else write to same directory as buffer file.  Popup
;; output buffer of execute result, with the buffer name as
;; "execute@temp-file-name".

;; Within the buffer, turned on the minor mode `temp-execute-mode',
;; with below keys binding to each buffer:

;; C-d to kill the output result buffer, delete the temp file.
;; C-o to open the temp file.

;;; Code:
(require 'winner)

(defvar temp-execute-default-dir temporary-file-directory
  "The default directory to store temporary files.
Initially set to `temporary-file-directory'")

(defvar temp-execute-filename nil
  "Buffer local var to save current temp file name.")

(defvar temp-execute-mode-map (make-sparse-keymap)
  "Buffer local var to save mode map.")

(progn
  (make-variable-buffer-local 'temp-execute-filename)
  (define-key temp-execute-mode-map (kbd "C-o") #'(lambda()
                                                    "Quickly open the temp file."
                                                    (interactive)
                                                    (find-file temp-execute-filename)))
  (define-key temp-execute-mode-map (kbd "C-d") #'(lambda()
                                                    "Quickly close the output buffer."
                                                    (interactive)
                                                    (delete-file temp-execute-filename)
                                                    (kill-this-buffer)
                                                    (winner-undo))))

(define-minor-mode temp-execute-mode
  "Temp-execute mode with temp file."
  :init-value nil
  :lighter " TempExecute"
  :keymap temp-execute-mode-map
  (when temp-execute-mode
    (message "C-d: close output and remove temp file.  C-o: open the temp file.")))

;; eval input string as args list
;; http://emacs.stackexchange.com/questions/19877/how-to-evaluate-elisp-code-contained-in-a-string
(defun temp-execute-eval-string (str)
  "Read and evaluate all forms in STR.
Return the results of all forms as a list."
  (let ((next 0)
        ret)
    (condition-case _err
        (while t
          (setq ret (cons (funcall (lambda (ret)
                                     (setq next (cdr ret))
                                     (eval (car ret)))
                                   (read-from-string str next))
                          ret)))
      (end-of-file))
    (nreverse ret)))

;;;###autoload
(defun temp-execute (&optional execute use-default-dir &rest args)
  "EXECUTE command by insert current buffer or region into temp file.
Write it into `temp-execute-default-dir' if USE-DEFAULT-DIR
or no buffer-file, else write to same dir as buffer-file.
ARGS will passed to EXECUTE."
  (interactive (list (read-from-minibuffer "Program to execute: ")
                     nil current-prefix-arg
                     (temp-execute-eval-string (read-string "Arguments (quote each item, `[FILE]` as placeholder): " "\"[FILE]\""))))
  (when (and args (called-interactively-p 'any))
    (setq args (car args)))
  (let* ((buffer-name (buffer-file-name))
         (temporary-file-directory (if (or use-default-dir (not (buffer-file-name)))
                                       temp-execute-default-dir
                                     (file-name-directory (buffer-file-name))))
         (file (make-temp-file execute nil (when buffer-name (file-name-extension buffer-name t))))
         (command-args (if args
                           (mapcar #'(lambda(item)
                                       (if (stringp item)
                                           (replace-regexp-in-string "\\[FILE\\]" file item t)
                                         (if (numberp item) (number-to-string item)
                                           (error "Arguments must be string or number"))))
                                   args)
                         (list file)))
         (start (if (use-region-p) (region-beginning) (point-min)))
         (end (if (use-region-p) (region-end) (point-max)))
         (content (buffer-substring start end))
         ;; make proc execute under the temp path
         (default-directory (file-name-directory file))
         proc name buffer)
    ;; when execute is nil
    (when (or (not (stringp execute)) (equal execute ""))
      (setq execute nil))
    (write-region content nil file)
    (setq name (concat "*" execute "@"
                       (file-name-nondirectory file) "*"))
    (setq buffer (create-file-buffer name))
    (pop-to-buffer buffer)
    (insert (format "generated below temp file for execute:\n%s" file))
    (insert (format "\n\nCommand line is:\n%s %s\n\n" execute command-args))
    ;; save filename local vars for each popup buffer
    (setq temp-execute-filename file)
    ;; Open the temp file in new buffer
    (temp-execute-mode 1)
    (if (not execute)
        (insert "file contents:\n\n" content)
      ;; only when execute non-nil, start the process
      (setq proc (apply #'start-process name buffer
                        execute
                        command-args))
      ;; without ask kill process on exit
      (set-process-query-on-exit-flag proc nil))
    ;; return temp file name
    file))

(defun temp-execute-node (use-default-dir)
  "Run `temp-execute' with node, USE-DEFAULT-DIR is passed as same meaning."
  (interactive "P")
  (temp-execute "node" use-default-dir))

(defun temp-execute-electron (use-default-dir)
  "Run `temp-execute' with electron, USE-DEFAULT-DIR is passed as same meaning."
  (interactive "P")
  (temp-execute "electron" use-default-dir))

(global-set-key (kbd "C-c C-b e") 'temp-execute)
(global-set-key (kbd "C-c C-b l") 'temp-execute-electron)
(global-set-key (kbd "C-c C-b n") 'temp-execute-node)

(provide 'temp-execute)
;;; temp-execute.el ends here