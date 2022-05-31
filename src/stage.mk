# # #
# INCLUDE FILE
# Not intended to be invoked directly, i.e. paths are relative to the main Makefile
# # # 

include mdo-require.mk
include mdo-cli.mk

stage: files-restore file-permissions load-mysql-dump replace-urls cms-config crm-config file-permissions set-checkout-dummy-pp

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

extract-archive: arch/html.tgz 
	tar -xzf arch/html.tgz -C ${WEB_ROOT} $(if ${REWRITE_UNTAR}, --xform '${REWRITE_UNTAR}')

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

drop-db-%: | require-env-MYSQL_CLI
	$(info $(MYSQL_CLI))
ifneq (TRUE,${AUTO_CONFIRM})
	$(call user-confirm,DROP DATABASE ${*}?)
endif
	echo 'DROP DATABASE ${*}; CREATE DATABASE ${*}' | $(MYSQL_CLI) -f

load-mysql-dump: arch/members.sql drop-db-${DATABASE} | require-env-MYSQL_CLI 
	$(info $(MYSQL_CLI))
ifneq (TRUE,${AUTO_CONFIRM})
	$(call user-confirm,RESTORE ${DATABASE}?)
endif
	$(MYSQL_CLI) ${DATABASE} < ${MYSQL_SRC_DUMP}

# # #
# Run Configs
# # #

SRDB_EXEC ?= srdb/srdb.cli.php

# wp: civicrm_setting,wp_options,wp_posts,wp_postmeta
# d7: menu_links,variable,sessions,users,block_custom,cache_menu,cache_form,wp_options
SRDB_CMD ?= php $(SRDB_EXEC) -h ${MYSQL_HOST} -u '${DATABASE_USER}' -p '${DATABASE_PASSWORD}' -t 'civicrm_setting,civicrm_setting,wp_options,wp_posts,wp_postmeta'

disable-ssl = $(SRDB_CMD) -n '${1}' -s 'https:' -r 'http:' 2>/dev/null
enable-ssl = $(SRDB_CMD) -n '${1}' -s 'http:' -r 'https:' 2>/dev/null
search-replace-host = $(SRDB_CMD) -n '${1}' -s '${SEARCH_HOST}' -r '${REPLACE_HOST}' 2>/dev/null

srdb:
	git clone git@github.com:interconnectit/search-replace-host-DB.git ${@}

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
