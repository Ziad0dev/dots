;;; init.el --- CL-focused Emacs -*- lexical-binding: t; -*-
;;; Lives in ~/dots/emacs/init.el, symlinked by home-manager.
;;; All packages come from Nix (programs.emacs.extraPackages) — nothing
;;; here downloads anything.

;;; --- UI / sanity -----------------------------------------------------
(setq inhibit-startup-screen t
      ring-bell-function #'ignore
      make-backup-files nil
      auto-save-default nil
      use-short-answers t
      custom-file (locate-user-emacs-file "custom.el")) ; keep customize noise out of dots
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)

(load-theme 'modus-vivendi t)           ; built-in; swap when an oxocarbon port lands
(add-to-list 'default-frame-alist '(alpha-background . 90)) ; pgtk-native transparency
;; (add-to-list 'default-frame-alist '(font . "YourMono-12"))

;;; --- Evil ------------------------------------------------------------
(setq evil-want-keybinding nil          ; must precede loading evil (evil-collection req)
      evil-want-C-u-scroll t
      evil-undo-system 'undo-redo)
(require 'evil)
(evil-mode 1)
(require 'evil-collection)
(evil-collection-init)

(require 'evil-escape)                  ; jk / kj, same as the nvim config
(setq evil-escape-key-sequence "jk"
      evil-escape-unordered-key-sequence t)
(evil-escape-mode 1)

(evil-set-leader 'normal (kbd "SPC"))

;;; --- Completion ------------------------------------------------------
(require 'corfu)
(global-corfu-mode 1)
(setq tab-always-indent 'complete)

;;; --- direnv: buffers inherit the flake devShell ----------------------
;; Open any file under tinygrad-cl/ and `sbcl` resolves to the flake's
;; sbcl.withPackages — so M-x sly just works, per project, declaratively.
(require 'envrc)
(envrc-global-mode 1)

;; was: (load-theme 'modus-vivendi t)
(require 'autothemer)
(add-to-list 'custom-theme-load-path "~/dots/emacs/themes/")
(load-theme 'oxocarbon t)
;;; --- Common Lisp / SLY -----------------------------------------------
(require 'sly)
(require 'sly-mrepl)
(setq inferior-lisp-program "sbcl"
      sly-symbol-completion-mode nil)   ; let corfu drive completion UI

(dolist (hook '(lisp-mode-hook
                emacs-lisp-mode-hook
                lisp-interaction-mode-hook
                sly-mrepl-mode-hook))
  (add-hook hook #'paredit-mode)
  (add-hook hook #'rainbow-delimiters-mode))

;; Leader bindings mirroring the important SLY chords:
(evil-define-key 'normal 'global
  (kbd "<leader>rr") #'sly                        ; start/attach REPL
  (kbd "<leader>rz") #'sly-mrepl                  ; jump to REPL buffer
  (kbd "<leader>ee") #'sly-eval-defun             ; eval toplevel form
  (kbd "<leader>cc") #'sly-compile-defun          ; recompile form into live image
  (kbd "<leader>ck") #'sly-compile-and-load-file  ; whole file
  (kbd "<leader>ii") #'sly-inspect                ; inspector on expr
  (kbd "<leader>dd") #'sly-documentation)         ; docstring lookup
;; M-. / M-, (jump to definition and back) come free via evil-collection,
;; and they jump into SBCL's own source too.

;;; init.el ends here
