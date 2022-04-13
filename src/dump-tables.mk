#
# Dump mysql tables, excluding tables as recommended by:
# - https://docs.civicrm.org/sysadmin/en/latest/misc/switch-servers/
#
# REQUIRES ENV:
# - DATABASE
# - MYSQL_CLI

SEARCH_SQL_GTID := ^SET @@GLOBAL\.GTID_PURGED.*$$
SEARCH_SQL_TEMP_LOGBIN := ^SET @MYSQLDUMP_TEMP_LOG_BIN.*$$
SEARCH_SQL_LOGBIN := ^SET @@SESSION.SQL_LOG_BIN.*$$
EXCLUDED_CACHE_TABLES := civicrm_acl_cache civicrm_acl_contact_cache civicrm_cache civicrm_group_contact_cache
DEFINER_REGEX := /\*![0-9]* DEFINER=[^*]*\*/ # includes trailing space; fwd-slashes are part of pattern;

mysql-dump = $(subst mysql,mysqldump,${MYSQL_CLI})

remove-in = sed 's%$1%%g'
define dump-table
    ${mysql-dump} --skip-comments --skip-dump-date ${DATABASE} $1 \
		| $(call remove-in,${DEFINER_REGEX}) \
		| $(call remove-in,${SEARCH_SQL_LOGBIN}) \
		| $(call remove-in,${SEARCH_SQL_TEMP_LOGBIN}) \
		| $(call remove-in,${SEARCH_SQL_GTID}) \
		>> $@

endef

grep-excludes := $(foreach e,${EXCLUDED_CACHE_TABLES}, -e $e)
tables-matching = echo "show tables like '$1';" | ${MYSQL_CLI} --skip-column-names ${DATABASE}

table-list := $(shell $(call tables-matching,civicrm_%) | grep -v ${grep-excludes}) $(shell $(call tables-matching,wp_%) | grep -v ${grep-excludes})

arch/${DATABASE}.sql:
	$(foreach tbl,${table-list},$(info ${tbl}) $(call dump-table,${tbl}))