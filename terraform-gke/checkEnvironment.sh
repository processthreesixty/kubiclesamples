export GOOGLE_APPLICATION_CREDENTIALS=/home/kubicle/.config/gcloud/application_default_credentials.json
echo $GOOGLE_APPLICATION_CREDENTIALS
gcloud auth application-default print-access-token
