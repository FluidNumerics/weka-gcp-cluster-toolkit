#!/bin/bash
#
# The terraform destroy provisioner only allows us to reference the 
# values stored by the parent resource; in this case, we're using the 
# `terraform_data` resource which provides a single field `input` that
# can be used. Here, the `input` field is set to the terminate uri and the
# cluster name separated by a `|` .

TERMINATE_CLUSTER_URI=$(echo $INPUT | awk -F "|" '{print $1}')
CLUSTER_NAME=$(echo $INPUT | awk -F "|" '{print $2}')

curl -m 70 -X POST "${TERMINATE_CLUSTER_URI}" \
-H "Authorization:bearer $(gcloud auth print-identity-token)" \
-H "Content-Type:application/json" \
-d "\{\"name\":\"$CLUSTER_NAME\"\}"