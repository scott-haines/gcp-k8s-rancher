VARIABLE_NAME=$1
. makefile-helpers/print-messages.sh

[[ -z "${!VARIABLE_NAME}" ]] && print_failure "$VARIABLE_NAME has not been set." && exit 0

print_success "$VARIABLE_NAME set to value \"${!VARIABLE_NAME}\""

exit 0