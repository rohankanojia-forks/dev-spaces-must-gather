#!/usr/bin/env bash
# Tests must-gather archive

LOGS_DIR="${LOGS_DIR:-must-gather}"

# These tests are to validate that the must-gather produced not only
# contains the right data, but is also legible to the standard `omc`
# tool used for reading them.

if [ ! -d "$LOGS_DIR" ]; then
    echo "Must-gather directory does not exist"
elif omc use "$LOGS_DIR" > /dev/null; then
    echo "✓ Must-gather is usable"
else
    echo "✗ Must-gather is not usable"
fi

# The only real check needed is to validate that, given a cluster with
# matching CRDs, `omc` can attempt to fetch all the resources for Dev
# Spaces from it.

RESOURCES=(
    checlusters.org.eclipse.che
    devworkspaceoperatorconfigs.controller.devfile.io
    devworkspaceroutings.controller.devfile.io
    devworkspaces.workspace.devfile.io
    devworkspacetemplates.workspace.devfile.io
    subscriptions.operators.coreos.com
    operators.operators.coreos.com
    operatorgroups.operators.coreos.com
    installplans.operators.coreos.com
    clusterserviceversions.operators.coreos.com
)

RESULTS=()
for resource in "${RESOURCES[@]}"; do
    if omc get "$resource" -A &> /dev/null; then
        echo "✓ Can fetch: $resource"
    else
        echo "✗ Couldn't fetch: $resource"
        RESULTS+=("$resource")
    fi
done

echo
if [ -n "${RESULTS[*]}" ]; then
    echo "Failed to collect: ${RESULTS[*]}"
    exit 1
else
    echo "All good!"
fi

