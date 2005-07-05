;;; url-news.el --- News Uniform Resource Locator retrieval code

;; Copyright (c) 1996 - 1999, 2004 Free Software Foundation, Inc.

;; Keywords: comm, data, processes

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'url-vars)
(require 'url-util)
(require 'url-parse)
(require 'nntp)
(autoload 'url-warn "url")
(autoload 'gnus-group-read-ephemeral-group "gnus-group")
(eval-when-compile (require 'cl))

(defgroup url-news nil
  "News related options."
  :group 'url)

(defun url-news-open-host (host port user pass)
  (if (fboundp 'nnheader-init-server-buffer)
      (nnheader-init-server-buffer))
  (nntp-open-server host (list port))
  (if (and user pass)
      (progn
	(nntp-send-command "^.*\r?\n" "AUTHINFO USER" user)
	(nntp-send-command "^.*\r?\n" "AUTHINFO PASS" pass)
	(if (not (nntp-server-opened host))
	    (url-warn 'url (format "NNTP authentication to `%s' as `%s' failed"
				   host user))))))

(defun url-news-fetch-message-id (host message-id)
  (let ((buf (generate-new-buffer " *url-news*")))
    (if (eq ?> (aref message-id (1- (length message-id))))
	nil
      (setq message-id (concat "<" message-id ">")))
    (if (cdr-safe (nntp-request-article message-id nil host buf))
	;; Successfully retrieved the article
	nil
      (save-excursion
	(set-buffer buf)
	(insert "Content-type: text/html\n\n"
		"<html>\n"
		" <head>\n"
		"  <title>Error</title>\n"
		" </head>\n"
		" <body>\n"
		"  <div>\n"
		"   <h1>Error requesting article...</h1>\n"
		"   <p>\n"
		"    The status message returned by the NNTP server was:"
		"<br><hr>\n"
		"    <xmp>\n"
		(nntp-status-message)
		"    </xmp>\n"
		"   </p>\n"
		"   <p>\n"
		"    If you If you feel this is an error, <a href=\""
		"mailto:" url-bug-address "\">send mail</a>\n"
		"   </p>\n"
		"  </div>\n"
		" </body>\n"
		"</html>\n"
		"<!-- Automatically generated by URL v" url-version " -->\n"
		)))
    buf))

(defun url-news-fetch-newsgroup (newsgroup host)
  (declare (special gnus-group-buffer))
  (if (string-match "^/+" newsgroup)
      (setq newsgroup (substring newsgroup (match-end 0))))
  (if (string-match "/+$" newsgroup)
      (setq newsgroup (substring newsgroup 0 (match-beginning 0))))

  ;; This saves us from checking new news if Gnus is already running
  ;; FIXME - is it relatively safe to use gnus-alive-p here? FIXME
  (if (or (not (get-buffer gnus-group-buffer))
	  (save-excursion
	    (set-buffer gnus-group-buffer)
	    (not (eq major-mode 'gnus-group-mode))))
      (gnus))
  (set-buffer gnus-group-buffer)
  (goto-char (point-min))
  (gnus-group-read-ephemeral-group newsgroup
				   (list 'nntp host
					 'nntp-open-connection-function
					 nntp-open-connection-function)
				   nil
				   (cons (current-buffer) 'browse)))

;;;###autoload
(defun url-news (url)
  ;; Find a news reference
  (let* ((host (or (url-host url) url-news-server))
	 (port (url-port url))
	 (article-brackets nil)
	 (buf nil)
	 (article (url-filename url)))
    (url-news-open-host host port (url-user url) (url-password url))
    (setq article (url-unhex-string article))
    (cond
     ((string-match "@" article)	; Its a specific article
      (setq buf (url-news-fetch-message-id host article)))
     ((string= article "")		; List all newsgroups
      (gnus))
     (t					; Whole newsgroup
      (url-news-fetch-newsgroup article host)))
    buf))

;;;###autoload
(defun url-snews (url)
  (let ((nntp-open-connection-function (if (eq 'tls url-gateway-method)
					   nntp-open-tls-stream
					 nntp-open-ssl-stream)))
    (url-news url)))

(provide 'url-news)

;;; arch-tag: 8975be13-04e8-4d38-bfff-47918e3ad311
;;; url-news.el ends here
