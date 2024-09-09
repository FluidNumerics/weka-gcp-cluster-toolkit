#!/bin/bash




echo "Waiting for WEKA to clusterize"
for i in $(seq 1 60); do

    # This command will query the weka cluster status cloud funtion
    # for the cluster status. The JSON output is parsed with python
    # to look for the value of the "clusterized" field. If this is
    # "True", then the cluster is ready for use. Otherwise, we sleep 
    # for 10 seconds and check again.
    clusterized=$(curl -s -m 70 -X POST "${WEKA_CLUSTER_STATUS_URI}" \
                        -H "Authorization:bearer $(gcloud auth print-identity-token)" \
                        -H "Content-Type:application/json" \
                        -d '{"type":"status"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['clusterized'])")
    if [[ "$clusterized" == "True" ]]; then
        echo "WEKA is clusterized"
    else
        sleep 10
    fi
done
        
