(in-package #:nyxt-user)

;;; Theme: themectl renders config/themes/_templates/nyxt.lisp.in into the
;;; state dir on every theme switch; `space u r' (or a restart) picks it up.

(defvar *dots-theme-file*
  (uiop:merge-pathnames* "dots/theme/nyxt.lisp"
                         (uiop:ensure-directory-pathname
                          (or (uiop:getenvp "XDG_STATE_HOME")
                              (uiop:subpathname (user-homedir-pathname)
                                                ".local/state/")))))

(defun dots-theme ()
  (or (ignore-errors (load *dots-theme-file*) (symbol-value '*dots-theme*))
      theme:+dark-theme+))

(define-configuration browser
  ((theme (dots-theme))
   (external-editor-program "ghostty --gtk-single-instance=false -e nvim")))

(define-command-global dots-reload-theme ()
  "Re-read the themectl palette and restyle the browser UI."
  (setf (theme *browser*) (dots-theme))
  (dolist (window (window-list))
    (print-status (status-buffer window)))
  (ffi-buffer-reload (current-buffer))
  (echo "Theme reloaded from ~a" *dots-theme-file*))

;;; Keys: one table drives the keymaps and the `space ?' cheatsheet.
;;; Mirrors config/nvim: H/L buffers, <space> leader with which-key groups.

(defparameter *dots-bindings*
  '(("Buffers (like nvim H/L, <leader>b)"
     ("H" switch-buffer-previous "Previous buffer")
     ("L" switch-buffer-next "Next buffer")
     ("space b d" delete-current-buffer "Delete buffer")
     ("space b o" delete-other-buffers "Delete other buffers")
     ("space b n" make-buffer-focus "New empty buffer")
     ("space b r" reopen-buffer "Reopen closed buffer")
     ("space e" nyxt/mode/buffer-listing:list-buffers "Buffer list (explorer)"))
    ("History (vim jumplist)"
     ("C-o" nyxt/mode/history:history-backwards "Back")
     ("C-i" nyxt/mode/history:history-forwards "Forward")
     ("space f r" nyxt/mode/history:list-history "Recent history"))
    ("Find (<leader>f)"
     ("space space" execute-command "Command palette")
     ("space f f" set-url "Open URL / search")
     ("space f F" set-url-new-buffer "Open URL in new buffer")
     ("space f b" switch-buffer "Pick buffer")
     ("space f g" nyxt/mode/search-buffer:search-buffers "Grep all buffers")
     ("space f /" nyxt/mode/search-buffer:search-buffer "Search this page")
     ("space /" nyxt/mode/search-buffer:search-buffer "Search this page")
     ("space f s" nyxt/mode/document:jump-to-heading "Page headings (symbols)")
     ("space f S" nyxt/mode/document:jump-to-heading-buffers "Headings, all buffers")
     ("space f m" nyxt/mode/bookmark:set-url-from-bookmark "Open bookmark")
     ("space f d" nyxt/mode/download:list-downloads "Downloads")
     ("space f h" describe-any "Help / describe anything")
     ("space f k" describe-bindings "All keymaps")
     ("space f c" edit-user-file-with-external-editor "Edit config in nvim"))
    ("Yank"
     ("y y" copy-url "Copy URL")
     ("y t" copy-title "Copy title")
     ("y f" nyxt/mode/hint:copy-hint-url "Copy a link's URL (hint)"))
    ("Edit"
     ("space c e" edit-with-external-editor "Edit focused field in nvim"))
    ("UI (<leader>u, <leader>t)"
     ("space u d" nyxt/mode/style:dark-mode "Toggle dark pages")
     ("space u r" dots-reload-theme "Reload themectl colors")
     ("space t z" toggle-toolbars "Zen: hide bars")
     ("space t Z" toggle-fullscreen "Fullscreen")
     ("escape" nyxt/mode/search-buffer:remove-search-marks "Clear search marks"))
    ("Quit"
     ("space q q" quit "Quit Nyxt")
     ("space ?" dots-cheatsheet "This cheatsheet")))
  "(group (keys command description) ...), bound in vi-normal.")

(defparameter *dots-alt-bindings*
  '(("Everywhere, even insert (tmux-style Alt)"
     ("M-h" switch-buffer-previous "Previous buffer")
     ("M-l" switch-buffer-next "Next buffer")
     ("M-c" make-buffer-focus "New buffer")
     ("M-Q" delete-current-buffer "Delete buffer")
     ("M-tab" switch-buffer-last "Last buffer"))))

;; Nyxt's own vi-normal bindings, listed only for the cheatsheet.
(defparameter *dots-builtin-bindings*
  '(("Built-in: move & view"
     ("j k h l" nil "Scroll")
     ("g g / G" nil "Top / bottom")
     ("C-f / C-b, space" nil "Page down / up")
     ("z i / z o / z z" nil "Zoom in / out / reset")
     ("g h" nil "Jump to heading"))
    ("Built-in: links & pages"
     ("f" nil "Follow hint")
     ("F" nil "Hint in new buffer (focus)")
     ("; f" nil "Hint in background buffer")
     ("o / O" nil "Open URL / in new buffer")
     ("R / r" nil "Reload page / pick buffers to reload")
     ("u" nil "Reopen closed buffer")
     ("d / D" nil "Pick buffers to close / close current"))
    ("Built-in: modes"
     ("i" nil "Insert mode (type in fields)")
     ("escape" nil "Back to normal mode")
     ("q" nil "Unfocus field")
     ("v" nil "Visual (caret) mode, y to copy")
     ("C-z" nil "Passthrough: send keys to page")
     ("/ , ?" nil "Search page / clear marks")
     ("m m / m o / m l" nil "Bookmark add / open / list")
     (":" nil "Command palette"))
    ("Built-in: prompt (opens in insert)"
     ("C-j / C-k" nil "Next / previous suggestion")
     ("return / M-return" nil "Run / pick action")
     ("escape, then j k" nil "Normal mode navigation")
     ("escape escape" nil "Close prompt"))))

(define-internal-page-command-global dots-cheatsheet ()
    (buffer "*Cheatsheet*")
  "Show the dots Nyxt keybindings."
  (spinneret:with-html-string
    (:nstyle
      (theme:themed-css (theme *browser*)
        '(body :max-width "70rem" :margin "0 auto" :padding "1.5rem")
        '(.grid :display "grid" :gap "1rem 2rem"
                :grid-template-columns "repeat(auto-fill, minmax(20rem, 1fr))")
        `(h2 :font-size "1rem" :margin "0 0 .4rem 0" :color ,theme:primary-color)
        '(table :width "100%" :border-collapse "collapse")
        '(td :padding ".15rem .3rem" :vertical-align "top")
        `(kbd :font-family ,theme:monospace-font-family
              :white-space "nowrap" :padding "0 .3rem" :border-radius "3px"
              :background-color ,theme:background-color+)))
    (:h1 "Nyxt cheatsheet")
    (:p "Leader is " (:kbd "space") " in normal mode, like nvim. "
        (:kbd "space space") " finds any command; "
        (:kbd "space f k") " lists every binding.")
    (:div :class "grid"
          (dolist (group (append *dots-bindings* *dots-alt-bindings*
                                 *dots-builtin-bindings*))
            (:section
             (:h2 (first group))
             (:table
              (dolist (binding (rest group))
                (:tr (:td (:kbd (first binding)))
                     (:td (third binding))))))))))

(defun dots-make-keymap (name groups &optional parent)
  (let ((keymap (if parent
                    (keymaps:make-keymap name parent)
                    (keymaps:make-keymap name))))
    (dolist (group groups keymap)
      (dolist (binding (rest group))
        (keymaps:define-key keymap (first binding) (second binding))))))

(defvar *dots-alt-keymap* (dots-make-keymap "dots-alt" *dots-alt-bindings*))
(defvar *dots-normal-keymap*
  (dots-make-keymap "dots-normal" *dots-bindings* *dots-alt-keymap*))

(define-mode dots-mode ()
  "Keybindings matching the dots Neovim and tmux setup."
  ((keyscheme-map (keymaps:make-keyscheme-map
                   nyxt/keyscheme:vi-normal *dots-normal-keymap*
                   nyxt/keyscheme:vi-insert *dots-alt-keymap*))))

;; Earlier default-modes win key lookups, so dots-mode shadows Nyxt's
;; defaults (e.g. H/L history becomes buffers, space leader beats page-down).
(define-configuration web-buffer
  ((default-modes (append '(dots-mode nyxt/mode/vi:vi-normal-mode) %slot-value%))))

;; Prompts start in insert so you can type immediately; C-j/C-k as in pickers.
(define-configuration prompt-buffer
  ((default-modes (append '(nyxt/mode/vi:vi-insert-mode) %slot-value%))))
