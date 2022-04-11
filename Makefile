include mdo-config.mk
include mdo-cli.mk
include mdo-require.mk

reset: files-restore file-permissions load-mysql-dump replace-urls cms-config crm-config file-permissions set-checkout-dummy-pp

TAR_EXCLUDES := \
	--exclude="wp-content/uploads/civicrm/ConfigAndLog" \
	--exclude="wp-content/uploads/civicrm/templates_c" \
	--exclude="wp-content/uploads/civicrm/upload" \
	--exclude="wp-content/uploads/civicrm/persist/contribute" \
	--exclude="wp-content/uploads/civicrm/custom" 

arch/html.tgz:
	ssh ${PROD_HOST} 'cd /var/www && tar czf html.tgz ${TAR_EXCLUDES} html'
	rsync ${PROD_HOST}:/var/www/html.tgz $@

arch/members.sql: | require-env-MYSQL_SRC_DUMP require-env-DATABASE_REPLACE_DEFINER require-env-DATABASE_USER require-env-MYSQL_CLI
	# dumping production database
	mysqldump --defaults-file=conf/my.root.cnf members >$@
	# replace user for views DEFINER
	sed -i 's#${DATABASE_REPLACE_DEFINER}#`${DATABASE_USER}`@`${MYSQL_HOST_IP}`#' ${MYSQL_SRC_DUMP}

freshen-snapshots:
	-test -f arch/html.tgz && rm arch/html.tgz
	-test -f arch/members.sql && rm arch/members.sql
	$(MAKE) arch/html.tgz arch/members.sql

# # #
# Files
# # #

drop-files:
	$(call user-confirm,"Delete all files in ${WEB_ROOT}?")
	@ echo 'Dropping files...';
	sudo chmod -R ug+rw ${WEB_ROOT}
	sudo rm -r ${WEB_ROOT}
	mkdir -p ${WEB_ROOT}

extract-archive: arch/html.tgz 
	tar -xzf arch/html.tgz -C ${WEB_ROOT} $(if ${REWRITE_UNTAR}, --xform ${REWRITE_UNTAR})

files-restore: drop-files extract-archive

file-permissions:
	sudo chown -R ${WEBSERVER_USER}:${WEBSERVER_USER} ${WEB_ROOT}
	sudo chmod -R 777 ${WEB_ROOT}

# # #
# Database
# # #

drop-db-%: | require-env-MYSQL_CLI
	echo 'DROP DATABASE ${*}; CREATE DATABASE ${*}' | $(MYSQL_CLI) -f

load-mysql-dump: arch/members.sql drop-db-${DATABASE} | require-env-MYSQL_CLI 
	$(MYSQL_CLI) ${DATABASE} < ${MYSQL_SRC_DUMP}

# # #
# Run Configs
# # #

SRDB_EXEC ?= srdb/srdb.cli.php

SRDB_CMD ?= php $(SRDB_EXEC) -h ${MYSQL_HOST} -u '${DATABASE_USER}' -p '${DATABASE_PASSWORD}' -t 'civicrm_setting,menu_links,variable,sessions,users,block_custom,cache_menu,cache_form'

disable-ssl = $(SRDB_CMD) -n '${1}' -s 'https:' -r 'http:' 2>/dev/null
enable-ssl = $(SRDB_CMD) -n '${1}' -s 'http:' -r 'https:' 2>/dev/null
remove-www = $(SRDB_CMD) -n '${1}' -s '://www.' -r '://' 2>/dev/null
search-replace = $(SRDB_CMD) -n '${1}' -s 'members.nadcp.org' -r '${SITENAME}' 2>/dev/null

srdb:
	git clone git@github.com:interconnectit/Search-Replace-DB.git ${@}

replace-urls: srdb | require-env-DATABASE
	#$(call remove-www,${DATABASE})
	$(call search-replace,${DATABASE})
	#$(call disable-ssl,${DATABASE})
	$(call enable-ssl,${DATABASE})

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

set-checkout-dummy-pp:
	echo "update civicrm_contribution_page SET payment_processor = 1 WHERE id IN (1,2);" \
	| $(MYSQL_CLI) ${DATABASE}
