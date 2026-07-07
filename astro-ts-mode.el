;;; astro-ts-mode.el --- Major mode for editing Astro templates  -*- lexical-binding: t; -*-

;; Copyright (C) 2023-2026  Ruby Iris Juric

;; Author: Ruby Iris Juric <ruby@srxl.me>
;; Homepage: https://github.com/Sorixelle/astro-ts-mode
;; Version: 3.0.1
;; Package-Requires: ((emacs "31"))
;; Keywords: languages

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides a major mode with syntax highlighting for Astro
;; templates. It leverages Emacs' built-in tree-sitter support, as well as
;; virchau13's tree-sitter grammar for Astro.
;;
;; More info:
;; README: https://github.com/Sorixelle/astro-ts-mode
;; tree-sitter-astro: https://github.com/virchau13/tree-sitter-astro
;; Astro: https://astro.build/

;;; Code:

(require 'treesit)
(require 'typescript-ts-mode)
(require 'css-mode)
(require 'html-ts-mode)

(eval-when-compile
  (require 'rx))

(defun astro-ts-mode-install-parsers ()
  "Install all tree-sitter parsers required for `astro-ts-mode' to function."
  (interactive)
  (mapc #'treesit-install-language-grammar '(astro css typescript)))

(add-to-list
 'treesit-language-source-alist
 '(astro "https://github.com/virchau13/tree-sitter-astro"
         :commit "213f6e6973d9b456c6e50e86f19f66877e7ef0ee")
 t)

(defgroup astro ()
  "Major mode for editing Astro templates."
  :group 'languages)

(defcustom astro-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `astro-ts-mode'."
  :type 'integer
  :group 'astro
  :package-version '(astro-ts-mode . "1.0.0"))

(defcustom astro-ts-mode-embedded-lang-in-name t
  "Whether to show the current embedded language (eg. TS, CSS) at point in the
mode's name."
  :type 'boolean
  :group 'astro
  :package-version '(astro-ts-mode . "4.0.0"))

(defvar astro-ts-mode--indent-rules
  `((astro
     ((parent-is "document") column-0 0)
     ((node-is "frontmatter") column-0 0)
     ((node-is "/>") parent-bol 0)
     ((node-is ">") parent-bol 0)
     ((node-is "end_tag") parent-bol 0)
     ((parent-is "comment") prev-adaptive-prefix 0)
     ((parent-is "element") parent-bol astro-ts-mode-indent-offset)
     ((parent-is "script_element") parent-bol astro-ts-mode-indent-offset)
     ((parent-is "style_element") parent-bol astro-ts-mode-indent-offset)
     ((parent-is "start_tag") parent-bol astro-ts-mode-indent-offset)
     ((parent-is "self_closing_tag") parent-bol astro-ts-mode-indent-offset))
    (css . ,(append '(((parent-is "stylesheet") parent-bol 0))
                    (alist-get 'css css--treesit-indent-rules)))
    (typescript . ,(append '(((parent-is "program") parent-bol 0))
                           (alist-get 'typescript (typescript-ts-mode--indent-rules 'typescript)))))
  "Tree-sitter indentation rules for `astro-ts-mode'.")

(defvar astro-ts-mode--font-lock-settings
  (append
   (typescript-ts-mode--font-lock-settings 'typescript)
   css--treesit-settings
   (treesit-font-lock-rules
    :language 'astro
    :feature 'comment
    '((comment) @font-lock-comment-face
      (frontmatter ("---") @font-lock-comment-face))

    :language 'astro
    :feature 'keyword
    '("doctype" @font-lock-keyword-face)

    :language 'astro
    :feature 'definition
    '((tag_name) @font-lock-function-name-face)

    :language 'astro
    :feature 'string
    '((quoted_attribute_value) @font-lock-string-face
      (attribute_name) @font-lock-constant-face)

    :language 'astro
    :feature 'bracket
    '((["<" ">" "</" "/>" "{" "}"]) @font-lock-bracket-face)))
  "Tree-sitter font-lock settings for `astro-ts-mode'.")

(defvar astro-ts-mode--font-lock-feature-list
  '((comment declaration definition selector query)
    (keyword string escape-sequence property)
    (constant expression identifier jsx number pattern property error variable operator)
    (function bracket delimiter))
  "Tree-sitter font-lock feature lists for `astro-ts-mode'.")

(defvar astro-ts-mode--range-settings
  (treesit-range-rules
   :embed 'typescript
   :host 'astro
   :local t
   '((frontmatter (frontmatter_js_block) @cap)
     (attribute_interpolation (attribute_js_expr) @cap)
     (html_interpolation (permissible_text) @cap)
     (script_element (raw_text) @cap))

   :embed 'css
   :host 'astro
   :local t
   '((style_element (raw_text) @cap)))
  "tree-sitter range settings for `astro-ts-mode'.")

(defvar astro-ts-mode--thing-settings
  (list
   ;; Astro's grammar derives from the HTML grammar, so we can mostly use it
   ;; here. The "list" type needs frontmatter nodes added to it, though, so we
   ;; just redefine it ourselves.
   `(astro
     ,(cons 'sexp (alist-get 'sexp (car html-ts-mode--treesit-things-settings)))
     (list ,(rx (or "doctype"
                    "element"
                    "comment"
                    "frontmatter")))
     ,(cons 'sentence (alist-get 'sentence (car html-ts-mode--treesit-things-settings)))
     ,(cons 'text (alist-get 'text (car html-ts-mode--treesit-things-settings)))
     (defun ,html-ts-mode--treesit-defun-type-regexp))
   ;; Definitions copied from typescript-ts-mode, since it doesn't store them in
   ;; a variable we can access, grumble grumble.
   `(typescript
     (sexp ,(regexp-opt
             (append typescript-ts-mode--sexp-nodes
                     '("jsx"))
             'symbols))
     (list ,(regexp-opt
             (append typescript-ts-mode--list-nodes
                     '("jsx_element"
                       "jsx_self_closing_element"
                       "jsx_expression"))
             'symbols))
     (sentence ,(regexp-opt
                 (append typescript-ts-mode--sentence-nodes
                         '("jsx_opening_element"
                           "jsx_attribute"
                           "jsx_closing_element"))
                 'symbols))
     (text ,(regexp-opt '("comment"
                          "template_string")
                        'symbols))
     (defun ,(cons typescript-ts-mode--defun-type-regexp
                   #'typescript-ts-mode--defun-predicate)))
   (append
    (car css--treesit-thing-settings)
    `((defun ,css--treesit-defun-type-regexp))))
  "Tree-sitter thing settings for `astro-ts-mode'.")

(defun astro-ts-mode--defun-name (node)
  "Returns the defun name for NODE."
  (let ((lang (treesit-node-language node)))
    (cond
     ((eq lang 'astro) (html-ts-mode--defun-name node))
     ((eq lang 'typescript) (typescript-ts-mode--defun-name node))
     ((eq lang 'css) (css--treesit-defun-name node)))))

(defun astro-ts-mode--outline-predicate (node)
  "Returns t if NODE is a frontmatter node or a multi-line HTML tag."
  (or (string-match-p "frontmatter" (treesit-node-type node))
      (html-ts-mode--outline-predicate node)))

(defvar astro-ts-mode--aggregated-outline-predicate
  `((astro . ,#'astro-ts-mode--outline-predicate)
    (typescript . ,typescript-ts-mode--outline-predicate)
    (css . ,css-ts-mode--outline-predicate))
  "Tree-sitter aggregated outline predicates for `astro-ts-mode'.")

(defun astro-ts-mode--embedded-lang-name-at-point ()
  "Returns the name of the embedded language (ie. non HTML) at point."
  (let ((lang (treesit-language-at (point))))
    (cond ((eq lang 'typescript) "[TS]")
          ((eq lang 'css) "[CSS]")
          (t ""))))

;;;###autoload
(define-derived-mode astro-ts-mode html-ts-mode
  '("Astro" (:eval (if astro-ts-mode-embedded-lang-in-name
                       (astro-ts-mode--embedded-lang-name-at-point)
                     "")))
  "Major mode for editing Astro templates, powered by tree-sitter."
  :group 'astro

  (unless (treesit-ready-p 'astro)
    (error "Tree-sitter grammar for Astro isn't available"))

  (unless (treesit-ready-p 'css)
    (error "Tree-sitter grammar for CSS isn't available"))

  (unless (treesit-ready-p 'typescript)
    (error "Tree-sitter grammar for Typescript isn't available"))

  (setq-local treesit-primary-parser (treesit-parser-create 'astro))

  ;; Things
  (setq-local treesit-thing-settings astro-ts-mode--thing-settings
              treesit-defun-name-function #'astro-ts-mode--defun-name)
  ;; html-ts-mode sets this, so we need to clear it, otherwise it takes
  ;; precedence over treesit-defun-name-function
  (kill-local-variable 'treesit-defun-type-regexp)

  ;; Indentation rules
  (setq-local treesit-simple-indent-rules astro-ts-mode--indent-rules
              css-indent-offset astro-ts-mode-indent-offset)

  ;; Font locking
  (setq-local treesit-font-lock-settings astro-ts-mode--font-lock-settings
              treesit-font-lock-feature-list astro-ts-mode--font-lock-feature-list)

  ;; Embedded languages
  (setq-local treesit-range-settings astro-ts-mode--range-settings)

  ;; Outline mode
  (setq-local treesit-aggregated-outline-predicate
              astro-ts-mode--aggregated-outline-predicate)

  (treesit-major-mode-setup))

;;;###autoload
(if (treesit-ready-p 'astro)
    (add-to-list 'auto-mode-alist '("\\.astro\\'" . astro-ts-mode)))

(provide 'astro-ts-mode)
;;; astro-ts-mode.el ends here
