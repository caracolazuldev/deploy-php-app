
# # #
# CiviCRM Utilities
# # #

set-checkout-dummy-pp:
	echo "update civicrm_contribution_page SET payment_processor = 1 WHERE id IN (1,2);" \
	| mysql --defaults-file=${MY_CNF} ${DATABASE}

mailing-backend:
ifdef CIVICRM_MAILING_BACKEND
	$(eval export CIVICRM_SETTINGS ?= $(shell find /var/www/html -name civicrm.settings.php))
	cat $(shell pwd)/${CIVICRM_MAILING_BACKEND} | cv api4 Setting.set --in=json 1>/dev/null
else
	# CIVICRM_MAILING_BACKEND is not defined
endif
