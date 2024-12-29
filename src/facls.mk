# Works on the current directory, plus configured PACKAGES and WEB_ROOT.
# Run with permission to sudo, or as root.
#
# Two modes: for single-user and multi-group (Dev, Admin)
# dev/default targets are single-user
# stage/shared for multi-group
#
# TIP: for dev/single-user, do not run with sudo, but ensure your user has
# sudo permissions. This is because single-user mode sets the file owner to
# the user the script is run as, i.e. root, which is not intended for this case.
#
# exec-bins grants x to npm bins in PACKAGES
# and any files in ./bin and ./sbin, if they exist
#
# Set WEB_WRITABLE for web-user to have write-permissions
# Auto-detects wordpress and drupal paths.
#

WEB_ROOT ?= /var/www/html/
PACKAGES ?= ./src/

GRP_ADMIN ?= sudo
GRP_DEV ?= ubuntu
USER_WEB ?= 33
GRP_WEB ?= ${USER_WEB}

SETFACL = ${SUDO} setfacl -Rm

USER_IS_ROOT := $(findstring root,$(shell groups))
USER_IN_SUDO_GROUP := $(findstring sudo,$(shell groups))
USER_MAY_SUDO := $(findstring is not allowed to run sudo,$(shell sudo -l))
ifdef USER_IS_ROOT
# ok
else ifdef USER_IN_SUDO_GROUP
# ok
else ifndef USER_MAY_SUDO
# ok
else
$(error # Did you forget to sudo?)
endif

#
# ACL TEMPLATES
#

# define a policy for existing and default
group-policy-tpl = d:g:$1:$2,g:$1:$2
user-policy-tpl = d:u:$1:$2,u:$1:$2

# POLICIES
group-writable = $(call group-policy-tpl,$1,rwX)
group-readable = $(call group-policy-tpl,$1,rX)
group-revoked = $(call group-policy-tpl,$1,-)

#
# AGGREGATE TARGETS
#

# Default action
# recommended schemes for single-user...
dev default: reset single-user base-grants web-grants exec-bins

# ...and shared (stage):
stage shared: shared-reset base-grants group-grants web-grants exec-bins

group-grants: revoke set-gid dev-readable dev-writable

base-grants: world-readable own-files

world-readable:
	# World Readable
	${SUDO} setfacl -m 'o::rX' ./
	${SUDO} setfacl -RLm 'd:o::rX,o::rX' ${WEB_ROOT} \
	$(and $(wildcard ${PACKAGES}), ${PACKAGES})

# Don't restrict a user from their own files
own-files:
	$(SETFACL) $(call user-policy-tpl,,rwX),$(call group-writable,${GRP_ADMIN}) ./
	$(SETFACL) $(call user-policy-tpl,,rwX),$(call group-writable,${GRP_ADMIN}) ${WEB_ROOT}

#
# WEB Grants
#

web-grants: web-writable arch-web-traversable

ifeq ($(wildcard ${WEB_ROOT}wp-content),${WEB_ROOT}wp-content)
WEB_WRITABLE := ${WEB_WRITABLE} ${WEB_ROOT}wp-content
endif
ifeq ($(wildcard ${WEB_ROOT}sites/default),${WEB_ROOT}sites/default)
WEB_WRITABLE := ${WEB_WRITABLE} $(shell find ${WEB_ROOT}sites/ -type d -name files | xargs)
endif

web-writable:
ifdef WEB_WRITABLE
	#
	# ${USER_WEB} can write in : ${WEB_WRITABLE}
	#
	$(SETFACL) $(call user-policy-tpl,${USER_WEB},rwX),$(call group-policy-tpl,${GRP_WEB},rwX) ${WEB_WRITABLE}
endif

# allow web to use /arch
# sus
arch-web-traversable:
	$(SETFACL) $(call group-policy-tpl,${USER_WEB},X) /var/www/arch

#
# EXECUTABLES
#
# Note: granting execute to files changes the behaviour of the X flag
#
exec-bins:
ifeq ($(wildcard ./bin),./bin)
	#
	# everyone can execute in bin/
	$(SETFACL) 'd:o::x,o::x' ./bin
	$(SETFACL) $(call group-policy-tpl,${GRP_ADMIN},rwx) ./bin
	$(SETFACL) $(call group-policy-tpl,${GRP_DEV},rwx) ./bin
endif
ifeq ($(wildcard ./sbin),./sbin)
	#
	# admins can execute in sbin/
	$(SETFACL) $(call group-policy-tpl,${GRP_ADMIN},rwx) ./sbin
endif
	#
	# enable npm bins
	-find ${PACKAGES}*/node_modules/.bin/* -exec ${SUDO} chmod ug+x '{}' \;

#
# RESET
#

clear-permissions = ${SUDO} chmod -R ug-st,a-rwx,ug+rwX $1
clear-acls = ${SUDO} setfacl --recursive --remove-all $1

reset:
	-$(call clear-permissions,./)
	-$(call clear-acls,./)
	-$(call clear-permissions,${WEB_ROOT})
	-$(call clear-acls,${WEB_ROOT})
.PHONY: reset

shared-fs-permissions = ${SUDO} chmod -R a=rwX,ug-st $1
clear-ownership = ${SUDO} chown -R nobody:nogroup $1

# for shared directories
shared-reset:
	$(call shared-fs-permissions, ./)
	$(call clear-ownership, ./)
	$(call clear-acls,./)
	$(call shared-fs-permissions,${WEB_ROOT})
	$(call clear-ownership,${WEB_ROOT})
	$(call clear-acls,${WEB_ROOT})
.PHONY: shared-reset

#
# SINGLE_USER GRANTS
#

take-ownership = ${SUDO} chown -R $(shell whoami) $1
private-fs-permissions = ${SUDO} chmod -R a-st,ug=rwX,o-rwx $1

single-user:
	$(call take-ownership,./)
	$(call private-fs-permissions, ./)
	$(call take-ownership,${WEB_ROOT})
	$(call private-fs-permissions, ${WEB_ROOT})

#
# SHARED GRANTS
#

set-gid = ${SUDO} find $1 -type d -exec chmod g+s {} \;

set-gid:
	$(call set-gid,./)
	$(call set-gid,${WEB_ROOT})
.phony: set-gid

# Set sticky-bit. You'd better know what you are doing.
set-sticky = ${SUDO} find $1 -type d -exec chmod o+t {} \;
# Sticky means, only an owner may remove a file. May be no use-case with ACLs?
set-sticky:
	$(call set-sticky,./)
	$(call set-sticky,${WEB_ROOT})

#
# Protect configs and assets, and admin executables
#

revoke-dir = $(SETFACL) $(call group-revoked,$2),d:o::-,o::- $1

# some recommended dirs to protect
revoke-%-conf revoke-%-arch revoke-%-sbin revoke-%-dumps:
	$(call revoke-dir,/var/www/conf,$*)

revoke:
	$(and $(wildcard /var/www/conf),$(call revoke-dir,/var/www/conf,${GRP_DEV}))
	$(and $(wildcard /var/www/arch),$(call revoke-dir,/var/www/arch,${GRP_DEV}))
	$(and $(wildcard ./sbin),$(call revoke-dir,./sbin,${GRP_DEV}))

dev-readable:
	# DEVs can read and traverse in project
	$(SETFACL) $(call group-readable,${GRP_DEV}) ./

DEV_WRITABLE := ${WEB_ROOT}
ifeq ($(wildcard /var/www/arch),./arch)
DEV_WRITABLE := ${DEV_WRITABLE} ./arch
endif
ifeq ($(wildcard ${PACKAGES}),${PACKAGES})
DEV_WRITABLE := ${DEV_WRITABLE} ${PACKAGES}
endif
ifeq ($(wildcard ./docs),./docs)
DEV_WRITABLE := ${DEV_WRITABLE} ./docs
endif
ifeq ($(wildcard ${WEB_ROOT}),${WEB_ROOT})
DEV_WRITABLE := ${DEV_WRITABLE} ${WEB_ROOT}
endif

dev-writable: dev-readable
	#
	# ${GRP_DEV} can write in: ${DEV_WRITABLE}
	#
	$(SETFACL) '$(call group-writable,${GRP_DEV})' ${DEV_WRITABLE}
