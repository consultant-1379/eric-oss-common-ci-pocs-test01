#! /bin/bash
#
# COPYRIGHT Ericsson 2021
#
#
#
# The copyright to the computer program(s) herein is the property of
#
# Ericsson Inc. The programs may be used and/or copied only with written
#
# permission from Ericsson Inc. or in accordance with the terms and
#
# conditions stipulated in the agreement/contract under which the
#
# program(s) have been supplied.
#

count=0
while true; do
  NOT_RUNNING=$(kubectl get pods -n $K8S_NAMESPACE --field-selector='status.phase!=Running' --no-headers | wc -l)
  RUNNING=$(kubectl get pods -n $K8S_NAMESPACE --field-selector='status.phase=Running' --no-headers | wc -l)
  POD_INFO=$(kubectl get pods -n $K8S_NAMESPACE)

  echo "Pods not running in the namespace: ${NOT_RUNNING}"
  echo "Pods running in the namespace: ${RUNNING}"
  if [[ "$NOT_RUNNING" -eq 0 && "$RUNNING" -gt 0 ]]; then
        echo "ALL PODS RUNNING"
        exit 0
  fi
  if [[ "$count" -gt 10 ]]; then
       echo "TIMEOUT"; echo "Pod Information:"; echo "${POD_INFO}"
       exit 1
  fi
  echo Check: $count
  sleep 15
  ((count++))
done
