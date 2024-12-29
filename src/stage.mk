# # #
# INCLUDE FILE
# Not intended to be invoked directly, i.e. paths are relative to the main Makefile
# # #

include mdo-require.mk
include mdo-cli.mk
include src/civi-util.mk

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
	${SUDO} chmod -R ug+rw ${WEB_ROOT}/
	-${SUDO} rm -r ${WEB_ROOT}* ${WEB_ROOT}/.*

extract-archive: ${FILES_ARCHIVE} file-permissions
	@# avoid setting permissions or timestamps: --touch --no-same-permissions
	tar -xzf ${FILES_ARCHIVE} -C ${WEB_ROOT} $(if ${REWRITE_UNTAR}, --xform '${REWRITE_UNTAR}') --touch --no-same-permissions

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

restore-db: load-mysql-dump replace-urls rebuild-triggers crm-config

drop-db-%: ${MYSQL_CNF} | require-env-MYSQL_CNF
	$(info mysql --defaults-file=${MYSQL_CNF})
ifneq (TRUE,${AUTO_CONFIRM})
	$(call user-confirm,Please confirm my.cnf file: DROP DATABASE ${*}?)
endif
	echo 'DROP DATABASE ${*}; CREATE DATABASE ${*}' | mysql --defaults-file=${MY_CNF} -f

load-mysql-dump: ${MYSQL_CNF} ${MYSQL_SRC_DUMP} drop-db-${DATABASE} | require-env-MYSQL_CNF
	$(info mysql --defaults-file=${MYSQL_CNF})
ifneq (TRUE,${AUTO_CONFIRM})
	$(call user-confirm,Please confirm my.cnf file: RESTORE ${DATABASE}?)
endif
	mysql --defaults-file=${MY_CNF} ${DATABASE} < ${MYSQL_SRC_DUMP}

rebuild-triggers:
	$(eval export CIVICRM_SETTINGS ?= $(shell find /var/www/html -name civicrm.settings.php))
	cv api4 System.flush '{"triggers":true}'

define my-cnf-tpl :=
[client]
host={{MYSQL_HOST}}
database = {{DATABASE}}
user = {{DATABASE_USER}}
password = {{DATABASE_PASSWORD}}

endef

# mysql-cli defaults-file:
conf/my%cnf:
	@echo "$$my-cnf-tpl" | ${REPLACE_TOKENS} > $@

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
	$(MAKE) -f src/civi-util.mk mailing-backend