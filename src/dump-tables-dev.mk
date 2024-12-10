#
# Dump mysql tables, excluding tables as recommended by:
# - https://docs.civicrm.org/sysadmin/en/latest/misc/switch-servers/
#
# Uses --set-gtid-purged=OFF with mysqldump
#
# REQUIRES ENV:
# - DATABASE
# - MYSQL_CNF (path to my.cnf)
#
# TIP:
#  - report on table sizes using `make table-sizes`
#

#
# CONFIGURE
#

EXCLUDED_DUMP_TABLES := civicrm_acl_cache civicrm_acl_contact_cache civicrm_cache civicrm_group_contact_cache civicrm_drupal_member_form_submissions civicrm_job_log civicrm_log civicrm_mailing_event_delivered civicrm_mailing_event_opened civicrm_mailing_event_queue civicrm_mailing_event_trackable_url_open civicrm_mailing_recipients civicrm_relationship_cache civicrm_subscription_history

SEARCH_SQL_TEMP_LOGBIN := ^SET @MYSQLDUMP_TEMP_LOG_BIN.*$$
SEARCH_SQL_LOGBIN := ^SET @@SESSION.SQL_LOG_BIN.*$$
DEFINER_REGEX := /\*![0-9]* DEFINER=[^*]*\*/ # includes trailing space; fwd-slashes are part of pattern, delimiter is %;

CONNECTION_COLLATION_80 := utf8mb4_0900_ai_ci
CONNECTION_COLLATION_LEGACY := utf8mb4_general_ci

ACTIVITY_ID_CUTOFF := 319953# last activity of 2021
#
# FUNCTIONS
#

mysql-dump = mysqldump --defaults-file=${MY_CNF}

remove-in = sed 's%$1%%g'
replace-in = sed 's%$1%$2%g'

# sub-routine of dump-table:
# when table is _activity_contact or _case_activity:= filter dump by activity_id field
# when table is _activity := filter dump by id field:
WHERE_ACTIVITY_ID = --where="$(or $(if $(or $(findstring contact,$1),$(findstring case,$1)), activity_id),id) > ${ACTIVITY_ID_CUTOFF}"

define dump-table
    ${mysql-dump} --skip-comments --skip-dump-date --set-gtid-purged=OFF \
		$(if $(findstring activity,$1),$(WHERE_ACTIVITY_ID)) \
		${DATABASE} $1 \
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

tables-matching = echo "show tables like '$1';" | mysql --defaults-file=${MY_CNF} --skip-column-names ${DATABASE}

table-list := $(shell $(call tables-matching,civicrm_%) | grep -v ${grep-excludes}) $(shell $(call tables-matching,wp_%) | grep -v ${grep-excludes}) $(shell $(call tables-matching,civirule_%) | grep -v ${grep-excludes})

arch/${DATABASE}-dev.sql:
	$(foreach tbl,${table-list},$(call dump-table,${tbl}))
	$(foreach tbl,${EXCLUDED_DUMP_TABLES},$(call dump-schema,${tbl}))

SQL_TABLES_BY_SIZE := SELECT table_name AS `Table`, round(((data_length + index_length) / 1024 / 1024), 2) `Size in MB`  FROM information_schema.TABLES  WHERE table_schema = "${DATABASE}" ORDER BY `Size in MB` DESC;

table-sizes:
	$(eval export SQL_TABLES_BY_SIZE)
	echo "$$SQL_TABLES_BY_SIZE" | mysql --defaults-file=${MY_CNF} --table
