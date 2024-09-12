#!/bin/bash


curl -m 70 -X POST "${TERMINATE_CLUSTER_URI}" \
-H "Authorization:bearer $(gcloud auth print-identity-token)" \
-H "Content-Type:application/json" \
-d "\{\"name\":\"$CLUSTER_NAME\"\}"