
README ?= USAGE.md

include mdo-help.mk
include mdo-config.mk
include mdo-cli.mk
# include mdo-wp.mk

include src/stage.mk

default: help

# # #
# Example integration for a dev-env
# # #


deploy: stage set-checkout-dummy-pp wp-enable-debug

mysql-cli:
	mysql --defaults-file=conf/my.cnf ${DATABASE}

clear-caches:
	cd ${WEB_ROOT} && wp cache flush
	cd ${WEB_ROOT} && wp civicrm cache-clear

# # #
# Snapshots
# # #

freshen-snapshots:
	-test -f arch/html.tgz && rm arch/html.tgz
	-test -f arch/members.sql && rm arch/members.sql
	$(MAKE) arch/html.tgz arch/members.sql

TAR_EXCLUDES ?= \
	"wp-content/uploads/civicrm/ConfigAndLog" \
	"wp-content/uploads/civicrm/templates_c" \
	"wp-content/uploads/civicrm/upload" \
	"wp-content/uploads/civicrm/persist/contribute" \
	"wp-content/uploads/civicrm/custom"

arch/html.tgz:
	ssh ${SSH_HOST_PROD} 'tar czf html.tgz $(foreach x,${TAR_EXCLUDES},--exclude=$x ) /var/www/html'
	rsync ${SSH_HOST_PROD}:~/html.tgz $@

arch/members.sql:
	# dumping production database
	MYSQL_CLI='mysql --defaults-file=conf/${MYSQL_CNF_PROD}' \
	DATABASE=${DATABASE} \
	$(MAKE) -f src/dump-tables.mk

arch/members-dev.sql:
	# dumping production database
	MYSQL_CLI='mysql --defaults-file=conf/${MYSQL_CNF_PROD}' \
	DATABASE=${DATABASE} \
	$(MAKE) -f src/dump-tables-dev.mk