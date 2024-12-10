# deploy-php-app
Manage configs, file-perms, and snapshots for a LAMP app

Available as a docker container: https://hub.docker.com/r/caracolazul/deploy-php-app

## Setup

Depends on https://github.com/caracolazul/make-do for make includes (`mdo-*.mk`).

## ENV Vars & Defaults

**conf/env.conf**:
```makefile
WEB_ROOT ?= /var/www/html# htdocs folder
SSH_HOST_PROD ?= # ssh hostname to fetch source snapshots
REWRITE_UNTAR ?= s@var/www/html@@# sed replace EXPRESSION for tar --xform=EXPRESSION
SEARCH_HOST ?= legacy-host# srdb host search-string
REPLACE_HOST ?= localhost# srdb host replace-string: include port if non-standard (80)
DISABLE_SSL ?= TRUE# boolean disable or enable SSL if not TRUE
AUTO_CONFIRM ?= TRUE# set TRUE to disable confirmation requests
CIVICRM_MAILING_BACKEND ?= conf/mailing_backend.mailhog.json# relative path to json input-file to cv api4 Setting.set
TAR_EXCLUDES ?=   #DEPRECATED '--exclude=' params when creating tarballs
```

**conf/db.conf**:
```makefile
MYSQL_SRC_DUMP ?= /var/www/arch/dump.sql# mysqldump file to restore
MYSQL_HOST ?= mysql# mysql hostname
DATABASE ?= mysql# database name
DATABASE_USER ?= mysql#
DATABASE_PASSWORD ?= strong-password#
MYSQL_CNF ?= conf/my.cnf# mysql credentials my.cnf file
MYSQL_CLI ?= mysql --defaults-file=${MYSQL_CNF}#DEPRECATED and un-used
MYSQL_CNF_PROD ?= mysql --defaults-file=conf/my.cnf.prod# DEPRECATED prod credentials my.cnf file
```

## Dump Tables

Maybe not useful in a containerized deployment of this project, but still potentially useful for local development.

The makefiles, `dump-tables.mk` and `dump-tables-dev.mk` create a full database dump, but doing one table at a time. This is done to facilitate excluding tables with an exclude-list, removing `DEFINER`, and other changes to support the portability of the dump.

The `-dev` version additionally supports truncating tables, providing a representative sample of a real database when migrating the full database is not practical.

Use the Source, Luke!

## Main Makefile

The top-level Makefile is a relic but serves as an example for integrating this code base when not using the containerized version.

## Search and Replace in DB

To migrate a LAMP app, it is often necessary to update URL's in the database. This is done with the `srdb` utility, which is included in the containerized version.

## Roadmap

Currently, geared towards CiviCRM deployment on Drupal or Wordpress. Would like to isolate platform-specific utils and clarify how they are enabled. Equally supporting both CMS's is already achieved. Using without CiviCRM is un-tested.
