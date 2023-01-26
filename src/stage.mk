# # #
# INCLUDE FILE
# Not intended to be invoked directly, i.e. paths are relative to the main Makefile
# # # 

include mdo-require.mk
include mdo-cli.mk

stage: files-restore file-permissions cms-config crm-config restore-db
	@# make will not make a target in the pre-req list more than once, so call explicitly again:
	$(MAKE) file-permissions

# # #
# Files
# # #

drop-files:
ifneq (TRUE,${AUTO_CONFIRM})
	$(call user-confirm,"Delete all files in ${WEB_ROOT}?")
endif
	@ echo 'Dropping files...';
	sudo chmod -R ug+rw ${WEB_ROOT}
	-sudo rm -r ${WEB_ROOT}* ${WEB_ROOT}.*

extract-archive: arch/html.tgz file-permissions
	@# avoid setting permissions or timestamps: --touch --no-same-permissions
	tar -xzf arch/html.tgz -C ${WEB_ROOT} $(if ${REWRITE_UNTAR}, --xform '${REWRITE_UNTAR}') --touch --no-same-permissions

files-restore: drop-files extract-archive

file-permissions:
ifdef FACLS_MODE
	$(MAKE) -f src/facls.mk ${FACLS_MODE}
else
	@# guess permissions mode based on host-name:
	$(MAKE) -f src/facls.mk $(if $(findstring localhost,${REPLACE_HOST}),dev,stage)
endif

# # #
# Database
# # #

restore-db: load-mysql-dump replace-urls rebuild-triggers crm-config mailing-backend

drop-db-%: | require-env-MYSQL_CLI
	$(info $(MYSQL_CLI))
ifneq (TRUE,${AUTO_CONFIRM})
	$(call user-confirm,Please confirm my.cnf file: DROP DATABASE ${*}?)
endif
	echo 'DROP DATABASE ${*}; CREATE DATABASE ${*}' | $(MYSQL_CLI) -f

load-mysql-dump: arch/members.sql drop-db-${DATABASE} | require-env-MYSQL_CLI 
	$(info $(MYSQL_CLI))
ifneq (TRUE,${AUTO_CONFIRM})
	$(call user-confirm,Please confirm my.cnf file: RESTORE ${DATABASE}?)
endif
	$(MYSQL_CLI) ${DATABASE} < ${MYSQL_SRC_DUMP}

rebuild-triggers:
	$(eval export CIVICRM_SETTINGS ?= $(shell find /var/www/html -name civicrm.settings.php))
	cv api4 System.flush '{"triggers":true}'

# # #
# Run Configs
# # #

SRDB_TABLES_WP := wp_options,wp_posts,wp_postmeta
SRDB_TABLES_D7 := menu_links,variable,sessions,users,block_custom,cache_menu,cache_form
SRDB_TABLES_CIVICRM := civicrm_setting,civicrm_contribution_page,civicrm_mailing_component,civicrm_mosaico_template,civicrm_msg_template,civicrm_navigation,civicrm_option_value,civicrm_report_instance,civicrm_saved_search
SRDB_TABLES_CIVICRM_FULL := civicrm_action_schedule,civicrm_activity,civicrm_mailing,civicrm_mailing_spool,civicrm_mailing_trackable_url

SRDB_TABLES ?= ${SRDB_TABLES_WP},${SRDB_TABLES_CIVICRM}
SRDB_EXEC ?= srdb/srdb.cli.php
SRDB_CMD ?= php $(SRDB_EXEC) -h ${MYSQL_HOST} -u '${DATABASE_USER}' -p '${DATABASE_PASSWORD}' -t '${SRDB_TABLES}'

disable-ssl = $(SRDB_CMD) -n '${1}' -s 'https:' -r 'http:' 2>/dev/null
enable-ssl = $(SRDB_CMD) -n '${1}' -s 'http:' -r 'https:' 2>/dev/null
search-replace-host = $(SRDB_CMD) -n '${1}' -s '${SEARCH_HOST}' -r '${REPLACE_HOST}' 2>/dev/null

srdb:
	git clone https://github.com/interconnectit/Search-Replace-DB.git ${@}

replace-urls: srdb | require-env-DATABASE
	$(call search-replace-host,${DATABASE})
ifeq (TRUE, ${DISABLE_SSL})
	$(call disable-ssl,${DATABASE})
else
	$(call enable-ssl,${DATABASE})
endif

enable-ssl: srdb | require-env-DATABASE
	$(call enable-ssl,${DATABASE})

disable-ssl: srdb | require-env-DATABASE
	$(call disable-ssl,${DATABASE})

cms-config:
	cp $(realpath conf/wp-settings.php) $(realpath ${WEB_ROOT})/wp-settings.php
	cp $(realpath conf/wp-config.php) $(realpath ${WEB_ROOT})/wp-config.php
	cp $(realpath conf/.htaccess) $(realpath ${WEB_ROOT})/.htaccess

crm-config:
	cp $(realpath conf/civicrm.settings.php) $(realpath ${WEB_ROOT}wp-content/uploads/civicrm)/civicrm.settings.php

mailing-backend:
ifdef CIVICRM_MAILING_BACKEND
	$(eval export CIVICRM_SETTINGS ?= $(shell find /var/www/html -name civicrm.settings.php))
	cat $(shell pwd)/${CIVICRM_MAILING_BACKEND} | cv api4 Setting.set --in=json 1>/dev/null
else
	# CIVICRM_MAILING_BACKEND is not defined
endif
