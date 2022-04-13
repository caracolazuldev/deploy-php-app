include mdo-config.mk
include mdo-cli.mk
include mdo-wp.mk

include src/stage.mk

default: stage set-checkout-dummy-pp wp-enable-debug

set-checkout-dummy-pp:
	echo "update civicrm_contribution_page SET payment_processor = 1 WHERE id IN (1,2);" \
	| $(MYSQL_CLI) ${DATABASE}

mysql-cli:
	mysql --defaults-file=conf/my.cnf ${DATABASE}

# # #
# Snapshots
# # #

freshen-snapshots:
	-test -f arch/html.tgz && rm arch/html.tgz
	-test -f arch/members.sql && rm arch/members.sql
	$(MAKE) arch/html.tgz arch/members.sql

TAR_EXCLUDES := \
	--exclude="wp-content/uploads/civicrm/ConfigAndLog" \
	--exclude="wp-content/uploads/civicrm/templates_c" \
	--exclude="wp-content/uploads/civicrm/upload" \
	--exclude="wp-content/uploads/civicrm/persist/contribute" \
	--exclude="wp-content/uploads/civicrm/custom" 

arch/html.tgz:
	ssh ${SSH_HOST_PROD} 'tar czf html.tgz ${TAR_EXCLUDES} /var/www/html'
	rsync ${SSH_HOST_PROD}:~/html.tgz $@

replace-in = sed -i 's%$1%$2%g'
remove-in = sed -i 's%$1%%g'
SEARCH_SQL_GTID := ^SET @@GLOBAL\.GTID_PURGED.*$$
SEARCH_SQL_TEMP_LOGBIN := ^SET @MYSQLDUMP_TEMP_LOG_BIN.*$$
SEARCH_SQL_LOGBIN := ^SET @@SESSION.SQL_LOG_BIN.*$$

arch/members.sql: export MYSQL_CLI := mysql --defaults-file=conf/${MYSQL_CNF_PROD}
arch/members.sql: export DATABASE
arch/members.sql: 
	# dumping production database
	$(info ${MYSQL_CLI})
	$(MAKE) -f src/dump-tables.mk
	#$(call remove-in,${SEARCH_SQL_LOGBIN}) $@ 
	#$(call remove-in,${SEARCH_SQL_TEMP_LOGBIN}) $@ 
	#$(call remove-in,${SEARCH_SQL_GTID}) $@ 
