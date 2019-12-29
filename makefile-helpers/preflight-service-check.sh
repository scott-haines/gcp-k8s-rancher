SERVICE=$1
. makefile-helpers/print-messages.sh
if [[ $(gcloud services list --format="value(config.name)" \
                              --filter="config.name:$SERVICE" 2>&1) != \
                              "$SERVICE" ]]; then
  print_failure "$SERVICE not enabled"
else
  print_success "$SERVICE is already enabled"
fi
exit 0