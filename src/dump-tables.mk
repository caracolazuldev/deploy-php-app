#
# Dump mysql tables, excluding tables as recommended by:
# - https://docs.civicrm.org/sysadmin/en/latest/misc/switch-servers/
#
# Uses --set-gtid-purged=OFF with mysqldump
#
# REQUIRES ENV:
# - DATABASE
# - MYSQL_CNF
#

#
# CONFIGURE
#

EXCLUDED_DUMP_TABLES := civicrm_acl_cache civicrm_acl_contact_cache civicrm_cache civicrm_group_contact_cache

SEARCH_SQL_TEMP_LOGBIN := ^SET @MYSQLDUMP_TEMP_LOG_BIN.*$$
SEARCH_SQL_LOGBIN := ^SET @@SESSION.SQL_LOG_BIN.*$$
DEFINER_REGEX := /\*![0-9]* DEFINER=[^*]*\*/ # includes trailing space; fwd-slashes are part of pattern, delimiter is %;

CONNECTION_COLLATION_80 := utf8mb4_0900_ai_ci
CONNECTION_COLLATION_LEGACY := utf8mb4_general_ci

#
# FUNCTIONS
#

mysql-dump = mysqldump --defaults-file=${MY_CNF}

remove-in = sed 's%$1%%g'
replace-in = sed 's%$1%$2%g'

define dump-table
    ${mysql-dump} --skip-comments --skip-dump-date --set-gtid-purged=OFF ${DATABASE} $1 \
		| $(call remove-in,${DEFINER_REGEX}) \
		| $(call remove-in,${SEARCH_SQL_LOGBIN}) \
		| $(call remove-in,${SEARCH_SQL_TEMP_LOGBIN}) \
		| $(call replace-in,${CONNECTION_COLLATION_80},${CONNECTION_COLLATION_LEGACY}) \
		>> $@

endef

define dump-schema
    ${mysql-dump} --skip-comments --skip-dump-date --set-gtid-purged=OFF --no-data ${DATABASE} $1 \
		| $(call remove-in,${DEFINER_REGEX}) \
		| $(call remove-in,${SEARCH_SQL_LOGBIN}) \
		| $(call remove-in,${SEARCH_SQL_TEMP_LOGBIN}) \
		| $(call replace-in,${CONNECTION_COLLATION_80},${CONNECTION_COLLATION_LEGACY}) \
		>> $@

endef

grep-excludes := $(foreach e,${EXCLUDED_DUMP_TABLES}, -e $e)

tables-matching = echo "show tables like '$1';" | mysql --defaults-file=${MYSQL_CNF} --skip-column-names ${DATABASE}

table-list := $(shell $(call tables-matching,civicrm_%) | grep -v ${grep-excludes}) $(shell $(call tables-matching,wp_%) | grep -v ${grep-excludes}) $(shell $(call tables-matching,civirule_%) | grep -v ${grep-excludes})

arch/${DATABASE}.sql:
	$(foreach tbl,${table-list},$(call dump-table,${tbl}))
	$(foreach tbl,${EXCLUDED_DUMP_TABLES},$(call dump-schema,${tbl}))
