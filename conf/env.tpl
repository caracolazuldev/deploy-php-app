export PROD_HOST ?= {{PROD_HOST}}# hostname (for ssh) to fetch source snapshots
export PROJ_ROOT ?= {{PROJ_ROOT}}# Project Root Directory
export WEB_ROOT ?= {{WEB_ROOT}}# HTDOCS Directory
export DATABASE ?= {{DATABASE}}# 
export DATABASE_USER ?= {{DATABASE_USER}}# 
export DATABASE_PASSWORD ?= {{DATABASE_PASSWORD}}# 
export WEBSITES ?= {{WEBSITES}}# /var/www
export SUPER_USER ?= {{SUPER_USER}}# 
export ADMIN_GROUP ?= {{ADMIN_GROUP}}# 
export USERS_GROUP ?= {{USERS_GROUP}}# 
export WEBSERVER_USER ?= {{WEBSERVER_USER}}# 
export MYSQL_CLI ?= {{MYSQL_CLI}}# 
MYSQL_HOST ?= {{MYSQL_HOST}}# mysql hostname
MYSQL_HOST_IP ?= {{MYSQL_HOST_IP}}# required for ... reasons
export DATABASE_REPLACE_DEFINER ?= {{DATABASE_REPLACE_DEFINER}}# db user in DEFINER of source db dumps;
export MYSQL_SRC_DUMP ?= {{MYSQL_SRC_DUMP}}# database to be restored
export SITENAME ?= {{SITENAME}}# Host-part of the URL of this instance
export WP_ADMIN_PASS ?= {{WP_ADMIN_PASS}}# WP admin password
