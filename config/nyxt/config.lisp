(in-package #:nyxt-user)

(defvar *dots-alt-keymap* (keymaps:make-keymap "dots-alt"))

(define-key *dots-alt-keymap*
  "M-h" 'switch-buffer-previous
  "M-l" 'switch-buffer-next
  "M-c" 'make-buffer-focus
  "M-Q" 'delete-current-buffer
  "M-tab" 'switch-buffer-last)

(defvar *dots-normal-keymap* (keymaps:make-keymap "dots-normal" *dots-alt-keymap*))

(define-key *dots-normal-keymap*
  "H" 'switch-buffer-previous
  "L" 'switch-buffer-next
  "C-o" 'nyxt/mode/history:history-backwards
  "C-i" 'nyxt/mode/history:history-forwards
  "y y" 'copy-url
  "space space" 'execute-command
  "space f f" 'set-url
  "space f b" 'switch-buffer
  "space f g" 'nyxt/mode/search-buffer:search-buffers
  "space f m" 'nyxt/mode/bookmark:set-url-from-bookmark
  "space f d" 'nyxt/mode/download:list-downloads
  "space f h" 'describe-any
  "space f k" 'describe-bindings
  "space e" 'nyxt/mode/buffer-listing:list-buffers
  "space /" 'nyxt/mode/search-buffer:search-buffer
  "space b d" 'delete-current-buffer
  "space q q" 'quit)

(define-mode dots-mode ()
  "Keybindings matching the dots Neovim and tmux setup."
  ((keyscheme-map (keymaps:make-keyscheme-map
                   nyxt/keyscheme:vi-normal *dots-normal-keymap*
                   nyxt/keyscheme:vi-insert *dots-alt-keymap*))))

(define-configuration input-buffer
  ((default-modes (append '(dots-mode nyxt/mode/vi:vi-normal-mode) %slot-value%))))
