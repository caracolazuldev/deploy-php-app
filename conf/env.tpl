WEB_ROOT ?= {{WEB_ROOT}}# htdocs folder
SSH_HOST_PROD ?= {{SSH_HOST_PROD}}# ssh hostname to fetch source snapshots
TAR_EXCLUDES ?= {{TAR_EXCLUDES}}#DEPRECATED '--exclude=' params when creating tarballs
REWRITE_UNTAR ?= {{REWRITE_UNTAR}}# sed replace EXPRESSION for tar --xform=EXPRESSION
SEARCH_HOST ?= {{SEARCH_HOST}}# srdb host search-string
REPLACE_HOST ?= {{REPLACE_HOST}}# srdb host replace-string
DISABLE_SSL ?= {{DISABLE_SSL}}# boolean disable or enable SSL if not TRUE
AUTO_CONFIRM ?= {{AUTO_CONFIRM}}# set TRUE to disable confirmation requests
CIVICRM_MAILING_BACKEND ?= {{CIVICRM_MAILING_BACKEND}}# relative path to json input-file to cv api4 Setting.set