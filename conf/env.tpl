WEB_ROOT ?= {{WEB_ROOT}}# htdocs folder
SSH_HOST_PROD ?= {{SSH_HOST_PROD}}# ssh hostname to fetch source snapshots
TAR_EXCLUDES ?= {{TAR_EXCLUDES}}# '--exclude=' params
REWRITE_UNTAR ?= {{REWRITE_UNTAR}}# sed replace EXPRESSION for tar --xform=EXPRESSION
SEARCH_HOST ?= {{SEARCH_HOST}}# srdb host search-string
REPLACE_HOST ?= {{REPLACE_HOST}}# srdb host replace-string
AUTO_CONFIRM ?= {{AUTO_CONFIRM}}# set TRUE to disable confirmation requests