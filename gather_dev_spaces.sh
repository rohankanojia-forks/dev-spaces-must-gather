#!/usr/bin/env bash
# This script automates the collection of OpenShift Dev Spaces resources from the cluster

# Fail loudly on errors, undeclared variables, and on pipeline failures
set -eu -o pipefail

LOGS_DIR="${LOGS_DIR:-must-gather}"

mkdir -p "$LOGS_DIR"

echo "Collecting Dev Spaces CRDs"

readarray -t CRDS < <(oc get crd -oname | grep -e devworkspace -e devfile -e "eclipse\.che")
oc adm inspect \
   "${CRDS[@]}" \
   customresourcedefinition/subscriptions.operators.coreos.com \
   customresourcedefinition/operators.operators.coreos.com \
   customresourcedefinition/operatorgroups.operators.coreos.com \
   customresourcedefinition/installplans.operators.coreos.com \
   customresourcedefinition/clusterserviceversions.operators.coreos.com \
   --dest-dir="$LOGS_DIR"

echo "Collecting Dev Spaces resources"

readarray -t API_RESOURCES < <(oc api-resources -oname | grep -e devworkspace -e devfile -e "eclipse\.che")
oc adm inspect $(sed 's/ /,/g' <<< "${API_RESOURCES[@]}") --all-namespaces --dest-dir="$LOGS_DIR"

echo "Collecting OLM resources"

# As it's possible to install the operator to multiple namespaces, collect them all and parse them individually
readarray -t DEV_SPACES_OPERATORS < <(oc get operators.operators.coreos.com --ignore-not-found -ojson | \
                                          jq -r '.items[] | select(.metadata.name | contains("devspaces") or contains("devworkspace")) | .metadata.name')
for operator in "${DEV_SPACES_OPERATORS[@]}"; do
    oc adm inspect operators.operators.coreos.com/"$operator" --dest-dir="$LOGS_DIR"
    # Check for and pull any subscriptions for this install of Dev Spaces
    SUBSCRIPTION=$(oc get operator "$operator" -ojson | jq -r '.status.components.refs[] | select(.kind == "Subscription")')
    if [ -n "$SUBSCRIPTION" ]; then
        SUBSCRIPTION_NAME=$(jq -r '.name' <<< "$SUBSCRIPTION")
        SUBSCRIPTION_NAMESPACE=$(jq -r '.namespace' <<< "$SUBSCRIPTION")
        oc adm inspect \
           subscription.operators.coreos.com/"$SUBSCRIPTION_NAME" \
           -n "$SUBSCRIPTION_NAMESPACE" \
           --dest-dir "$LOGS_DIR"
    fi
    CSV=$(oc get operator "$operator" -ojson | jq -r '.status.components.refs[] | select(.kind == "ClusterServiceVersion")')
    if [ -n "$CSV" ]; then
        CSV_NAME=$(jq -r '.name' <<< "$CSV")
        CSV_NAMESPACE=$(jq -r '.namespace' <<< "$CSV")
        oc adm inspect \
           clusterserviceversions.operators.coreos.com/"$CSV_NAME" \
           -n "$CSV_NAMESPACE" \
           --dest-dir "$LOGS_DIR"
    fi
done

echo "Collecting workspace data"

# Gather the projects associated with Dev Workspaces by their unique label

readarray -t DEV_SPACES_NAMESPACES < <(oc get namespaces -l 'app.kubernetes.io/component=workspaces-namespace' -oname)
oc adm inspect "${DEV_SPACES_NAMESPACES[@]}" --dest-dir="$LOGS_DIR"

sync
