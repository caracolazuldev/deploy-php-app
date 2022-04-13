#
# Dump mysql tables, excluding tables as recommended by:
# - https://docs.civicrm.org/sysadmin/en/latest/misc/switch-servers/
#
# REQUIRES ENV:
# - DATABASE
# - MYSQL_CLI

MYSQL_DUMP = $(subst mysql,mysqldump,${MYSQL_CLI})

rm-definer = sed 's%/\*![0-9]* DEFINER=[^*]*/%%'

define dump-table
        ${MYSQL_DUMP} --skip-comments --skip-dump-date ${DATABASE} $1 | ${rm-definer} >> $@

endef

civi-tables := $(shell echo "show tables like 'civicrm_%';" | ${MYSQL_CLI} --skip-column-names ${DATABASE})
wp-tables := $(shell echo "show tables like 'wp_%';" | ${MYSQL_CLI} --skip-column-names ${DATABASE})

exclude-cache-tables := civicrm_acl_cache civicrm_acl_contact_cache civicrm_cache civicrm_group_contact_cache
grep-excludes := $(foreach e,${exclude-cache-tables}, -e $e)
table-list := $(shell echo "${civi-tables}\n${wp-tables}" | grep -v ${grep-excludes})

civicrm.dump.sql:
	$(foreach tbl,${table-list},$(call dump-table,${tbl}))