;;; rockit-lsp.el --- LSP configuration for Rockit -*- lexical-binding: t; -*-

;; Rockit Language Server configuration for Emacs
;;
;; Requires: lsp-mode (https://emacs-lsp.github.io/lsp-mode/)
;;
;; Add to your init.el:
;;   (load "/path/to/rockit-lsp.el")
;;
;; Or with use-package:
;;   (use-package lsp-mode
;;     :hook (rockit-mode . lsp-deferred)
;;     :config
;;     (load "/path/to/rockit-lsp.el"))

(require 'lsp-mode)

(add-to-list 'lsp-language-id-configuration '(rockit-mode . "rockit"))

(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection '("rockit" "lsp"))
  :activation-fn (lsp-activate-on "rockit")
  :server-id 'rockit-lsp
  :priority -1))

;; Minimal major mode for .rok files (if you don't have one yet)
(unless (fboundp 'rockit-mode)
  (define-derived-mode rockit-mode prog-mode "Rockit"
    "Major mode for editing Rockit source files."
    (setq-local comment-start "// ")
    (setq-local comment-end ""))
  (add-to-list 'auto-mode-alist '("\\.rok\\'" . rockit-mode)))

;;; Eglot alternative (built-in to Emacs 29+):
;;
;; (add-to-list 'eglot-server-programs '(rockit-mode "rockit" "lsp"))
;; (add-hook 'rockit-mode-hook 'eglot-ensure)

(provide 'rockit-lsp)
;;; rockit-lsp.el ends here
