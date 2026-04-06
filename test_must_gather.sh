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

# Required resources (must be present)
REQUIRED_RESOURCES=(
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

# Optional resources (may not exist in all OpenShift versions)
OPTIONAL_RESOURCES=(
    packages.operators.coreos.com
)

RESULTS=()
for resource in "${REQUIRED_RESOURCES[@]}"; do
    if omc get "$resource" -A &> /dev/null; then
        echo "✓ Can fetch: $resource"
    else
        echo "✗ Couldn't fetch: $resource"
        RESULTS+=("$resource")
    fi
done

for resource in "${OPTIONAL_RESOURCES[@]}"; do
    if omc get "$resource" -A &> /dev/null; then
        echo "✓ Can fetch: $resource"
    else
        echo "✗ Couldn't fetch: $resource (may not exist in cluster)"
    fi
done

# Validate collected directories and files (oc adm inspect structure)
echo
echo "Validating collected structure..."

# Check for webhook configurations
if find "$LOGS_DIR/cluster-scoped-resources/admissionregistration.k8s.io/mutatingwebhookconfigurations" -name "*.devfile.io.yaml" 2>/dev/null | grep -q .; then
    echo "✓ Mutating webhooks collected"
else
    echo "✗ Mutating webhooks missing"
    RESULTS+=("mutatingwebhooks")
fi

if find "$LOGS_DIR/cluster-scoped-resources/admissionregistration.k8s.io/validatingwebhookconfigurations" -name "*.devfile.io.yaml" 2>/dev/null | grep -q .; then
    echo "✓ Validating webhooks collected"
else
    echo "✗ Validating webhooks missing"
    RESULTS+=("validatingwebhooks")
fi

# Check for storage resources
if [ -d "$LOGS_DIR/cluster-scoped-resources/storage.k8s.io/storageclasses" ] && [ -n "$(ls -A "$LOGS_DIR/cluster-scoped-resources/storage.k8s.io/storageclasses" 2>/dev/null)" ]; then
    echo "✓ Storage classes collected"
else
    echo "✗ Storage classes missing"
    RESULTS+=("storageclasses")
fi

if [ -d "$LOGS_DIR/cluster-scoped-resources/core/persistentvolumes" ] || [ -d "$LOGS_DIR/cluster-scoped-resources/v1/persistentvolumes" ]; then
    echo "✓ Persistent volumes collected"
else
    echo "✗ Persistent volumes missing"
    RESULTS+=("persistentvolumes")
fi

# Check for nodes
if [ -d "$LOGS_DIR/cluster-scoped-resources/core/nodes" ] || [ -d "$LOGS_DIR/cluster-scoped-resources/v1/nodes" ]; then
    echo "✓ Nodes collected"
else
    echo "✗ Nodes missing"
    RESULTS+=("nodes")
fi

# Check for events
if find "$LOGS_DIR/namespaces" -name "events.yaml" 2>/dev/null | grep -q .; then
    echo "✓ Events collected"
else
    echo "✗ Events missing"
    RESULTS+=("events")
fi

# Check for cluster version
if [ -d "$LOGS_DIR/cluster-scoped-resources/config.openshift.io/clusterversions" ] && [ -n "$(ls -A "$LOGS_DIR/cluster-scoped-resources/config.openshift.io/clusterversions" 2>/dev/null)" ]; then
    echo "✓ Cluster version collected"
else
    echo "✗ Cluster version missing"
    RESULTS+=("clusterversion")
fi

# Check for SecurityContextConstraints
if find "$LOGS_DIR/cluster-scoped-resources" -name "securitycontextconstraints" -type d 2>/dev/null | grep -q .; then
    echo "✓ SecurityContextConstraints collected"
else
    echo "✗ SecurityContextConstraints missing (may not exist in cluster)"
fi

# Check for ClusterRoles
if find "$LOGS_DIR/cluster-scoped-resources" -path "*/rbac.authorization.k8s.io/clusterroles/*" -name "*.yaml" 2>/dev/null | grep -qE 'devworkspace|che|devfile'; then
    echo "✓ ClusterRoles collected"
else
    echo "✗ ClusterRoles missing (may not exist in cluster)"
fi

# Check for ClusterRoleBindings
if find "$LOGS_DIR/cluster-scoped-resources" -path "*/rbac.authorization.k8s.io/clusterrolebindings/*" -name "*.yaml" 2>/dev/null | grep -qE 'devworkspace|che|devfile'; then
    echo "✓ ClusterRoleBindings collected"
else
    echo "✗ ClusterRoleBindings missing (may not exist in cluster)"
fi

# Check for cluster-wide pods listing
if [ -f "$LOGS_DIR/cluster-resources/pods-all-namespaces.yaml" ] && [ -s "$LOGS_DIR/cluster-resources/pods-all-namespaces.yaml" ]; then
    echo "✓ Cluster-wide pods listing collected"
else
    echo "✗ Cluster-wide pods listing missing"
    RESULTS+=("cluster-pods")
fi

# Check for cluster status
if [ -f "$LOGS_DIR/cluster-resources/cluster-status.txt" ]; then
    echo "✓ Cluster status collected"
else
    echo "✗ Cluster status missing"
    RESULTS+=("cluster-status")
fi

# Check for ImageContentSourcePolicy
if [ -d "$LOGS_DIR/cluster-scoped-resources/operator.openshift.io/imagecontentsourcepolicies" ]; then
    echo "✓ ImageContentSourcePolicy collected"
else
    echo "✗ ImageContentSourcePolicy missing (may not exist in cluster)"
fi

# Check for Cluster Proxy
if [ -d "$LOGS_DIR/cluster-scoped-resources/config.openshift.io/proxies" ]; then
    echo "✓ Cluster Proxy collected"
else
    echo "✗ Cluster Proxy missing (may not exist in cluster)"
fi

# Check for PackageManifests (all catalogs)
if find "$LOGS_DIR" -path "*/packages.operators.coreos.com/packagemanifests/*.yaml" 2>/dev/null | grep -q .; then
    echo "✓ PackageManifests collected"
else
    echo "✗ PackageManifests missing (may not exist in cluster)"
fi

# Check for oc version output
if [ -f "$LOGS_DIR/cluster-resources/oc-version.txt" ] && [ -s "$LOGS_DIR/cluster-resources/oc-version.txt" ]; then
    echo "✓ oc version output collected"
else
    echo "✗ oc version output missing"
    RESULTS+=("oc-version")
fi

# Check for workspace namespace descriptions
if [ -d "$LOGS_DIR/workspace-namespaces" ]; then
    if find "$LOGS_DIR/workspace-namespaces" -name "*-description.txt" 2>/dev/null | grep -q .; then
        echo "✓ Workspace namespace descriptions collected"
    else
        echo "✗ Workspace namespace descriptions missing (may not exist in cluster)"
    fi

    if find "$LOGS_DIR/workspace-namespaces" -path "*/pod-descriptions/*.txt" 2>/dev/null | grep -q .; then
        echo "✓ Workspace pod descriptions collected"
    else
        echo "✗ Workspace pod descriptions missing (may not exist in cluster)"
    fi

    if find "$LOGS_DIR/workspace-namespaces" -path "*/pod-descriptions/*.log" 2>/dev/null | grep -q .; then
        echo "✓ Workspace pod logs collected (current)"
    else
        echo "✗ Workspace pod logs missing (may not exist in cluster)"
    fi

    if find "$LOGS_DIR/workspace-namespaces" -path "*/pod-descriptions/*-previous.log" 2>/dev/null | grep -q .; then
        echo "✓ Workspace pod logs collected (previous)"
    else
        echo "✗ Workspace pod logs (previous) missing (may not exist in cluster)"
    fi
fi

# Check for operator namespace descriptions
if [ -d "$LOGS_DIR/operator-namespaces" ]; then
    if find "$LOGS_DIR/operator-namespaces" -name "*-description.txt" 2>/dev/null | grep -q .; then
        echo "✓ Operator namespace descriptions collected"
    else
        echo "✗ Operator namespace descriptions missing (may not exist in cluster)"
    fi

    if find "$LOGS_DIR/operator-namespaces" -path "*/pod-descriptions/*.txt" 2>/dev/null | grep -q .; then
        echo "✓ Operator pod descriptions collected"
    else
        echo "✗ Operator pod descriptions missing (may not exist in cluster)"
    fi

    if find "$LOGS_DIR/operator-namespaces" -path "*/pod-descriptions/*.log" 2>/dev/null | grep -q .; then
        echo "✓ Operator pod logs collected (current)"
    else
        echo "✗ Operator pod logs missing (may not exist in cluster)"
    fi

    if find "$LOGS_DIR/operator-namespaces" -path "*/pod-descriptions/*-previous.log" 2>/dev/null | grep -q .; then
        echo "✓ Operator pod logs collected (previous)"
    else
        echo "✗ Operator pod logs (previous) missing (may not exist in cluster)"
    fi
fi

echo
if [ -n "${RESULTS[*]}" ]; then
    echo "Failed to collect: ${RESULTS[*]}"
    exit 1
else
    echo "All good!"
fi

