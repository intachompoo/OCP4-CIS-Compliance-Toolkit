#!/bin/bash

#################################################################################
# OCP4 CIS MANUAL Controls Evidence Collection Script
# 
# Purpose: Automatically collect evidence for all MANUAL compliance controls
# Output: Organized evidence files for documentation and audit purposes
#
# Usage: ./collect-manual-controls-evidence.sh
#################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="/tmp/ocp4-cis-manual-evidence-${TIMESTAMP}"
SUMMARY_FILE="${OUTPUT_DIR}/00-SUMMARY.txt"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   OCP4 CIS MANUAL Controls Evidence Collection               ║${NC}"
echo -e "${BLUE}║   Timestamp: ${TIMESTAMP}                             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Initialize summary
cat > "${SUMMARY_FILE}" << EOF
OCP4 CIS MANUAL Controls Evidence Collection Summary
=====================================================
Collection Date: $(date)
Cluster: $(oc whoami --show-server 2>/dev/null || echo "Unknown")
User: $(oc whoami 2>/dev/null || echo "Unknown")

Evidence Files Generated:
-------------------------
EOF

#################################################################################
# Helper Functions
#################################################################################

print_section() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

add_to_summary() {
    echo "$1" >> "${SUMMARY_FILE}"
}

#################################################################################
# 1. RBAC Controls
#################################################################################

collect_rbac_evidence() {
    print_section "1. RBAC CONTROLS"
    local OUTPUT_FILE="${OUTPUT_DIR}/01-rbac-controls.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "RBAC Controls Evidence Collection"
        echo "Collection Date: $(date)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        # 1.1 cluster-admin bindings
        echo "─────────────────────────────────────────────────────────────"
        echo "1.1 cluster-admin Role Bindings"
        echo "Control: ais-ocp4-cis-rbac-limit-cluster-admin"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get clusterrolebindings -o json | jq -r '\''.items[] | select(.roleRef.name=="cluster-admin") | {binding: .metadata.name, subjects: .subjects}'\'''
        echo ""
        echo "Output:"
        oc get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | {binding: .metadata.name, subjects: .subjects}' 2>/dev/null || echo "Error collecting data"
        echo ""
        echo "Summary:"
        CLUSTER_ADMIN_COUNT=$(oc get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[]?' 2>/dev/null | wc -l)
        echo "Total cluster-admin bindings: ${CLUSTER_ADMIN_COUNT}"
        echo ""
        
        # 1.2 Wildcard permissions
        echo "─────────────────────────────────────────────────────────────"
        echo "1.2 ClusterRoles with Wildcard Permissions"
        echo "Control: ais-ocp4-cis-rbac-wildcard-use"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get clusterroles -o json | jq -r '\''.items[] | select(.rules[]? | ((.verbs // []) | contains(["*"])) or ((.resources // []) | contains(["*"])) or ((.apiGroups // []) | contains(["*"]))) | .metadata.name'\'' | sort -u'
        echo ""
        echo "Output:"
        oc get clusterroles -o json | jq -r '.items[] | select(.rules[]? | ((.verbs // []) | contains(["*"])) or ((.resources // []) | contains(["*"])) or ((.apiGroups // []) | contains(["*"]))) | .metadata.name' 2>/dev/null | sort -u || echo "Error collecting data"
        echo ""
        WILDCARD_COUNT=$(oc get clusterroles -o json | jq -r '.items[] | select(.rules[]? | ((.verbs // []) | contains(["*"]))) | .metadata.name' 2>/dev/null | wc -l)
        echo "Total ClusterRoles with wildcards: ${WILDCARD_COUNT}"
        echo ""
        
        # 1.3 Secrets access
        echo "─────────────────────────────────────────────────────────────"
        echo "1.3 Roles with Secrets Access"
        echo "Control: ais-ocp4-cis-rbac-limit-secrets-access"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get clusterroles -o json | jq -r '\''.items[] | select(.rules[]? | (.resources // []) | contains(["secrets"])) | .metadata.name'\'''
        echo ""
        echo "Output:"
        oc get clusterroles -o json | jq -r '.items[] | select(.rules[]? | (.resources // []) | contains(["secrets"])) | .metadata.name' 2>/dev/null || echo "Error collecting data"
        echo ""
        
        # 1.4 Pod creation access
        echo "─────────────────────────────────────────────────────────────"
        echo "1.4 Users/SAs with Pod Creation Access (Sample Namespaces)"
        echo "Control: ais-ocp4-cis-rbac-pod-creation-access"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        for ns in default openshift-config openshift-kube-apiserver; do
            echo "Namespace: $ns"
            echo "Command: oc adm policy who-can create pods -n $ns"
            oc adm policy who-can create pods -n "$ns" 2>/dev/null || echo "Error or namespace not found"
            echo ""
        done
        
    } > "${OUTPUT_FILE}"
    
    print_success "RBAC evidence collected: ${OUTPUT_FILE}"
    add_to_summary "✓ 01-rbac-controls.txt - RBAC permissions and bindings"
}

#################################################################################
# 2. SCC Controls
#################################################################################

collect_scc_evidence() {
    print_section "2. SCC (Security Context Constraints) CONTROLS"
    local OUTPUT_FILE="${OUTPUT_DIR}/02-scc-controls.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "SCC Controls Evidence Collection"
        echo "Collection Date: $(date)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        # 2.1 Privileged containers
        echo "─────────────────────────────────────────────────────────────"
        echo "2.1 Pods Using Privileged SCC"
        echo "Control: ais-ocp4-cis-scc-limit-privileged-containers"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get pods --all-namespaces -o json | jq -r '\''.items[] | select(.metadata.annotations."openshift.io/scc" == "privileged") | "\(.metadata.namespace)/\(.metadata.name)"'\'''
        echo ""
        echo "Output:"
        oc get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations."openshift.io/scc" == "privileged") | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "Error collecting data"
        echo ""
        PRIV_POD_COUNT=$(oc get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.annotations."openshift.io/scc" == "privileged") | .metadata.name' 2>/dev/null | wc -l)
        echo "Total privileged pods: ${PRIV_POD_COUNT}"
        echo ""
        
        # 2.2 Root containers
        echo "─────────────────────────────────────────────────────────────"
        echo "2.2 Pods Running as Root (Sample)"
        echo "Control: ais-ocp4-cis-scc-limit-root-containers"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get pods --all-namespaces -o json | jq -r '\''.items[] | select(.spec.containers[]?.securityContext?.runAsUser == 0 or .spec.securityContext?.runAsUser == 0) | "\(.metadata.namespace)/\(.metadata.name)"'\'''
        echo ""
        echo "Output (first 20):"
        oc get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[]?.securityContext?.runAsUser == 0 or .spec.securityContext?.runAsUser == 0) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null | head -20 || echo "Error collecting data"
        echo ""
        
        # 2.3 SCCs with dangerous capabilities
        echo "─────────────────────────────────────────────────────────────"
        echo "2.3 SCCs with NET_RAW Capability"
        echo "Control: ais-ocp4-cis-scc-limit-net-raw-capability"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get scc -o json | jq -r '\''.items[] | select(.allowedCapabilities // [] | contains(["NET_RAW"])) | .metadata.name'\'''
        echo ""
        echo "Output:"
        oc get scc -o json | jq -r '.items[] | select(.allowedCapabilities // [] | contains(["NET_RAW"])) | .metadata.name' 2>/dev/null || echo "No SCCs with NET_RAW found"
        echo ""
        
        # 2.4 Required dropped capabilities
        echo "─────────────────────────────────────────────────────────────"
        echo "2.4 SCCs and Required Dropped Capabilities"
        echo "Control: ais-ocp4-cis-scc-drop-container-capabilities"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get scc -o json | jq -r '\''.items[] | {name: .metadata.name, requiredDropCapabilities: .requiredDropCapabilities}'\'''
        echo ""
        echo "Output:"
        oc get scc -o json | jq -r '.items[] | {name: .metadata.name, requiredDropCapabilities: .requiredDropCapabilities}' 2>/dev/null || echo "Error collecting data"
        echo ""
        
        # 2.5 Privilege escalation
        echo "─────────────────────────────────────────────────────────────"
        echo "2.5 SCCs Allowing Privilege Escalation"
        echo "Control: ais-ocp4-cis-scc-limit-privilege-escalation"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get scc -o json | jq -r '\''.items[] | select(.allowPrivilegeEscalation == true) | .metadata.name'\'''
        echo ""
        echo "Output:"
        oc get scc -o json | jq -r '.items[] | select(.allowPrivilegeEscalation == true) | .metadata.name' 2>/dev/null || echo "Error collecting data"
        echo ""
        
        # 2.6 Host namespaces
        echo "─────────────────────────────────────────────────────────────"
        echo "2.6 SCCs with Host Namespace Access"
        echo "Controls: limit-ipc-namespace, limit-network-namespace, limit-process-id-namespace"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Host IPC:"
        oc get scc -o json | jq -r '.items[] | select(.allowHostIPC == true) | .metadata.name' 2>/dev/null || echo "Error"
        echo ""
        echo "Host Network:"
        oc get scc -o json | jq -r '.items[] | select(.allowHostNetwork == true) | .metadata.name' 2>/dev/null || echo "Error"
        echo ""
        echo "Host PID:"
        oc get scc -o json | jq -r '.items[] | select(.allowHostPID == true) | .metadata.name' 2>/dev/null || echo "Error"
        echo ""
        
        # 2.7 SCC usage summary
        echo "─────────────────────────────────────────────────────────────"
        echo "2.7 SCC Usage Across Cluster (Top 20)"
        echo "Control: ais-ocp4-cis-general-apply-scc"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get pods --all-namespaces -o json | jq -r '\''.items[] | "\(.metadata.annotations."openshift.io/scc")"'\'' | sort | uniq -c | sort -rn'
        echo ""
        echo "Output:"
        oc get pods --all-namespaces -o json | jq -r '.items[] | "\(.metadata.annotations."openshift.io/scc")"' 2>/dev/null | sort | uniq -c | sort -rn | head -20 || echo "Error collecting data"
        echo ""
        
    } > "${OUTPUT_FILE}"
    
    print_success "SCC evidence collected: ${OUTPUT_FILE}"
    add_to_summary "✓ 02-scc-controls.txt - Security Context Constraints analysis"
}

#################################################################################
# 3. Namespace and Workload Controls
#################################################################################

collect_namespace_evidence() {
    print_section "3. NAMESPACE AND WORKLOAD CONTROLS"
    local OUTPUT_FILE="${OUTPUT_DIR}/03-namespace-controls.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "Namespace and Workload Controls Evidence Collection"
        echo "Collection Date: $(date)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        # 3.1 Default namespace usage
        echo "─────────────────────────────────────────────────────────────"
        echo "3.1 Resources in Default Namespace"
        echo "Control: ais-ocp4-cis-general-default-namespace-use"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command: oc get all -n default"
        echo ""
        echo "Output:"
        oc get all -n default 2>/dev/null || echo "Error accessing default namespace"
        echo ""
        
        # 3.2 Namespaces in use
        echo "─────────────────────────────────────────────────────────────"
        echo "3.2 All Namespaces"
        echo "Control: ais-ocp4-cis-general-namespaces-in-use"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command: oc get namespaces"
        echo ""
        echo "Output:"
        oc get namespaces 2>/dev/null || echo "Error listing namespaces"
        echo ""
        
        TOTAL_NS=$(oc get namespaces --no-headers 2>/dev/null | wc -l)
        echo "Total namespaces: ${TOTAL_NS}"
        echo ""
        
        # 3.3 Empty namespaces (sample check)
        echo "─────────────────────────────────────────────────────────────"
        echo "3.3 Potentially Empty Namespaces (First 10 non-openshift)"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        for ns in $(oc get namespaces -o json | jq -r '.items[] | select(.metadata.name | startswith("openshift") | not) | select(.metadata.name != "default" and .metadata.name != "kube-system" and .metadata.name != "kube-public" and .metadata.name != "kube-node-lease") | .metadata.name' 2>/dev/null | head -10); do
            POD_COUNT=$(oc get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
            echo "Namespace: $ns - Pods: ${POD_COUNT}"
        done
        echo ""
        
        # 3.4 Seccomp profiles
        echo "─────────────────────────────────────────────────────────────"
        echo "3.4 Pods Without Seccomp Profile (Sample - First 20)"
        echo "Control: ais-ocp4-cis-general-default-seccomp-profile"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get pods --all-namespaces -o json | jq -r '\''.items[] | select(.spec.securityContext.seccompProfile == null and (.spec.containers[].securityContext.seccompProfile == null or .spec.containers[].securityContext.seccompProfile == null)) | "\(.metadata.namespace)/\(.metadata.name)"'\'''
        echo ""
        echo "Output:"
        oc get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.securityContext.seccompProfile == null) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null | head -20 || echo "Error collecting data"
        echo ""
        
    } > "${OUTPUT_FILE}"
    
    print_success "Namespace evidence collected: ${OUTPUT_FILE}"
    add_to_summary "✓ 03-namespace-controls.txt - Namespace usage and configuration"
}

#################################################################################
# 4. Secrets Management Controls
#################################################################################

collect_secrets_evidence() {
    print_section "4. SECRETS MANAGEMENT CONTROLS"
    local OUTPUT_FILE="${OUTPUT_DIR}/04-secrets-controls.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "Secrets Management Controls Evidence Collection"
        echo "Collection Date: $(date)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        # 4.1 Secrets in environment variables
        echo "─────────────────────────────────────────────────────────────"
        echo "4.1 Pods Using Secrets via Environment Variables (Sample - First 20)"
        echo "Control: ais-ocp4-cis-secrets-no-environment-variables"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get pods --all-namespaces -o json | jq -r '\''.items[] | select(.spec.containers[].env[]?.valueFrom.secretKeyRef != null) | "\(.metadata.namespace)/\(.metadata.name)"'\'''
        echo ""
        echo "Output:"
        oc get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.containers[].env[]?.valueFrom.secretKeyRef != null) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null | head -20 || echo "Error collecting data"
        echo ""
        
        # 4.2 Total secrets count
        echo "─────────────────────────────────────────────────────────────"
        echo "4.2 Secrets Summary by Namespace (Top 20)"
        echo "Control: ais-ocp4-cis-secrets-consider-external-storage"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command: oc get secrets --all-namespaces"
        echo ""
        echo "Output:"
        for ns in $(oc get namespaces -o json | jq -r '.items[].metadata.name' 2>/dev/null | head -20); do
            SECRET_COUNT=$(oc get secrets -n "$ns" --no-headers 2>/dev/null | wc -l)
            if [ "$SECRET_COUNT" -gt 0 ]; then
                echo "Namespace: $ns - Secrets: ${SECRET_COUNT}"
            fi
        done
        echo ""
        
        TOTAL_SECRETS=$(oc get secrets --all-namespaces --no-headers 2>/dev/null | wc -l)
        echo "Total secrets in cluster: ${TOTAL_SECRETS}"
        echo ""
        
        echo "Note: Consider using external secret management solutions like:"
        echo "  - HashiCorp Vault"
        echo "  - External Secrets Operator"
        echo "  - AWS Secrets Manager / Azure Key Vault / GCP Secret Manager"
        echo ""
        
    } > "${OUTPUT_FILE}"
    
    print_success "Secrets evidence collected: ${OUTPUT_FILE}"
    add_to_summary "✓ 04-secrets-controls.txt - Secrets management analysis"
}

#################################################################################
# 5. Service Account Controls
#################################################################################

collect_serviceaccount_evidence() {
    print_section "5. SERVICE ACCOUNT CONTROLS"
    local OUTPUT_FILE="${OUTPUT_DIR}/05-serviceaccount-controls.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "Service Account Controls Evidence Collection"
        echo "Collection Date: $(date)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        # 5.1 Auto-mount service account tokens
        echo "─────────────────────────────────────────────────────────────"
        echo "5.1 Pods Auto-Mounting Service Account Tokens (Sample - First 20)"
        echo "Control: ais-ocp4-cis-accounts-restrict-service-account-tokens"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get pods --all-namespaces -o json | jq -r '\''.items[] | select(.spec.automountServiceAccountToken != false) | "\(.metadata.namespace)/\(.metadata.name)"'\'''
        echo ""
        echo "Output:"
        oc get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.automountServiceAccountToken != false) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null | head -20 || echo "Error collecting data"
        echo ""
        
        # 5.2 Default service account usage
        echo "─────────────────────────────────────────────────────────────"
        echo "5.2 Pods Using Default Service Account (Sample - First 20)"
        echo "Control: ais-ocp4-cis-accounts-unique-service-account"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command:"
        echo 'oc get pods --all-namespaces -o json | jq -r '\''.items[] | select(.spec.serviceAccountName == "default" or .spec.serviceAccountName == null) | "\(.metadata.namespace)/\(.metadata.name)"'\'''
        echo ""
        echo "Output:"
        oc get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.serviceAccountName == "default" or .spec.serviceAccountName == null) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null | head -20 || echo "Error collecting data"
        echo ""
        
        # 5.3 Service accounts summary
        echo "─────────────────────────────────────────────────────────────"
        echo "5.3 Service Accounts per Namespace (Top 20)"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        for ns in $(oc get namespaces -o json | jq -r '.items[].metadata.name' 2>/dev/null | head -20); do
            SA_COUNT=$(oc get sa -n "$ns" --no-headers 2>/dev/null | wc -l)
            if [ "$SA_COUNT" -gt 1 ]; then  # Skip if only default SA
                echo "Namespace: $ns - Service Accounts: ${SA_COUNT}"
            fi
        done
        echo ""
        
    } > "${OUTPUT_FILE}"
    
    print_success "Service Account evidence collected: ${OUTPUT_FILE}"
    add_to_summary "✓ 05-serviceaccount-controls.txt - Service account usage"
}

#################################################################################
# 6. Compliance Check Results
#################################################################################

collect_compliance_results() {
    print_section "6. COMPLIANCE OPERATOR RESULTS"
    local OUTPUT_FILE="${OUTPUT_DIR}/06-compliance-results.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "Compliance Operator Results"
        echo "Collection Date: $(date)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        # 6.1 List all MANUAL controls
        echo "─────────────────────────────────────────────────────────────"
        echo "6.1 All MANUAL Controls from Compliance Scan"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        echo "Command: oc get compliancecheckresult -n openshift-compliance | grep MANUAL"
        echo ""
        echo "Output:"
        oc get compliancecheckresult -n openshift-compliance 2>/dev/null | grep MANUAL || echo "No compliance results found or operator not installed"
        echo ""
        
        MANUAL_COUNT=$(oc get compliancecheckresult -n openshift-compliance 2>/dev/null | grep -c MANUAL || echo 0)
        echo "Total MANUAL controls: ${MANUAL_COUNT}"
        echo ""
        
        # 6.2 Get detailed info for each MANUAL control
        echo "─────────────────────────────────────────────────────────────"
        echo "6.2 Detailed MANUAL Control Information"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
        
        # Get all MANUAL controls
        MANUAL_CONTROLS=$(oc get compliancecheckresult -n openshift-compliance 2>/dev/null | grep MANUAL | awk '{print $1}')
        MANUAL_CONTROL_COUNT=$(echo "$MANUAL_CONTROLS" | wc -l)
        
        echo "Total MANUAL controls found: ${MANUAL_CONTROL_COUNT}"
        echo ""
        echo "Showing first 10 controls in detail (full list in section 6.1):"
        echo ""
        
        # Show detailed info for first 10 controls only (to keep file size manageable)
        for control in $(echo "$MANUAL_CONTROLS" | head -10); do
            echo "Control: $control"
            echo "---"
            oc describe compliancecheckresult "$control" -n openshift-compliance 2>/dev/null | head -30
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
        done
        
        if [ "$MANUAL_CONTROL_COUNT" -gt 10 ]; then
            echo ""
            echo "Note: Only showing first 10 controls in detail above."
            echo "      See section 6.1 for complete list of all ${MANUAL_CONTROL_COUNT} MANUAL controls."
            echo ""
        fi
        
    } > "${OUTPUT_FILE}"
    
    print_success "Compliance results collected: ${OUTPUT_FILE}"
    add_to_summary "✓ 06-compliance-results.txt - Compliance Operator scan results"
}

#################################################################################
# 7. Cluster Information
#################################################################################

collect_cluster_info() {
    print_section "7. CLUSTER INFORMATION"
    local OUTPUT_FILE="${OUTPUT_DIR}/07-cluster-info.txt"
    
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "Cluster Information"
        echo "Collection Date: $(date)"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        
        echo "─────────────────────────────────────────────────────────────"
        echo "Cluster Version"
        echo "─────────────────────────────────────────────────────────────"
        oc version 2>/dev/null || echo "Error getting version"
        echo ""
        
        echo "─────────────────────────────────────────────────────────────"
        echo "Cluster Operators"
        echo "─────────────────────────────────────────────────────────────"
        oc get clusteroperators 2>/dev/null || echo "Error getting cluster operators"
        echo ""
        
        echo "─────────────────────────────────────────────────────────────"
        echo "Nodes"
        echo "─────────────────────────────────────────────────────────────"
        oc get nodes 2>/dev/null || echo "Error getting nodes"
        echo ""
        
        echo "─────────────────────────────────────────────────────────────"
        echo "Node Counts"
        echo "─────────────────────────────────────────────────────────────"
        MASTER_COUNT=$(oc get nodes -l node-role.kubernetes.io/master --no-headers 2>/dev/null | wc -l)
        WORKER_COUNT=$(oc get nodes -l node-role.kubernetes.io/worker --no-headers 2>/dev/null | wc -l)
        echo "Master nodes: ${MASTER_COUNT}"
        echo "Worker nodes: ${WORKER_COUNT}"
        echo ""
        
    } > "${OUTPUT_FILE}"
    
    print_success "Cluster info collected: ${OUTPUT_FILE}"
    add_to_summary "✓ 07-cluster-info.txt - Cluster configuration and status"
}

#################################################################################
# 8. Generate Review Checklist
#################################################################################

generate_checklist() {
    print_section "8. GENERATING REVIEW CHECKLIST"
    local CHECKLIST_FILE="${OUTPUT_DIR}/08-REVIEW-CHECKLIST.txt"
    
    cat > "${CHECKLIST_FILE}" << 'EOF'
═══════════════════════════════════════════════════════════════
OCP4 CIS MANUAL CONTROLS REVIEW CHECKLIST
═══════════════════════════════════════════════════════════════

Instructions:
1. Review each control using the evidence collected
2. Mark each control as Compliant (✓) or Non-Compliant (✗)
3. Document findings and justifications
4. Obtain approval from Security Manager/CISO

───────────────────────────────────────────────────────────────
RBAC CONTROLS
───────────────────────────────────────────────────────────────

[ ] ais-ocp4-cis-rbac-least-privilege (HIGH)
    Evidence File: 01-rbac-controls.txt (Section 1.1, 1.2)
    Review: All RBAC bindings follow least privilege principle
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-rbac-limit-cluster-admin (MEDIUM)
    Evidence File: 01-rbac-controls.txt (Section 1.1)
    Review: cluster-admin limited to essential users/SAs only
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-rbac-limit-secrets-access (MEDIUM)
    Evidence File: 01-rbac-controls.txt (Section 1.3)
    Review: Secrets access limited to necessary roles
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-rbac-pod-creation-access (MEDIUM)
    Evidence File: 01-rbac-controls.txt (Section 1.4)
    Review: Pod creation limited to appropriate users/SAs
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-rbac-wildcard-use (MEDIUM)
    Evidence File: 01-rbac-controls.txt (Section 1.2)
    Review: Wildcard permissions limited to system roles
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

───────────────────────────────────────────────────────────────
SCC CONTROLS
───────────────────────────────────────────────────────────────

[ ] ais-ocp4-cis-scc-limit-privileged-containers (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.1)
    Review: Only essential pods use privileged SCC
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-scc-limit-root-containers (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.2)
    Review: Root containers limited to necessary workloads
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-scc-limit-privilege-escalation (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.5)
    Review: Privilege escalation properly controlled
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-scc-drop-container-capabilities (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.4)
    Review: SCCs drop unnecessary capabilities
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-scc-limit-net-raw-capability (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.3)
    Review: NET_RAW capability limited to necessary SCCs
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-scc-limit-ipc-namespace (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.6)
    Review: Host IPC access properly limited
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-scc-limit-network-namespace (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.6)
    Review: Host network access properly limited
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-scc-limit-process-id-namespace (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.6)
    Review: Host PID access properly limited
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

───────────────────────────────────────────────────────────────
GENERAL CONTROLS
───────────────────────────────────────────────────────────────

[ ] ais-ocp4-cis-general-apply-scc (MEDIUM)
    Evidence File: 02-scc-controls.txt (Section 2.7)
    Review: Workloads use appropriate SCCs
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-general-default-namespace-use (MEDIUM)
    Evidence File: 03-namespace-controls.txt (Section 3.1)
    Review: Default namespace not used for workloads
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-general-default-seccomp-profile (MEDIUM)
    Evidence File: 03-namespace-controls.txt (Section 3.4)
    Review: Pods use appropriate seccomp profiles
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-general-namespaces-in-use (MEDIUM)
    Evidence File: 03-namespace-controls.txt (Section 3.2, 3.3)
    Review: All namespaces are actively used
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

───────────────────────────────────────────────────────────────
SECRETS CONTROLS
───────────────────────────────────────────────────────────────

[ ] ais-ocp4-cis-secrets-consider-external-storage (MEDIUM)
    Evidence File: 04-secrets-controls.txt (Section 4.2)
    Review: External secret management considered/implemented
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-secrets-no-environment-variables (MEDIUM)
    Evidence File: 04-secrets-controls.txt (Section 4.1)
    Review: Secrets not exposed via environment variables
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

───────────────────────────────────────────────────────────────
SERVICE ACCOUNT CONTROLS
───────────────────────────────────────────────────────────────

[ ] ais-ocp4-cis-accounts-restrict-service-account-tokens (MEDIUM)
    Evidence File: 05-serviceaccount-controls.txt (Section 5.1)
    Review: SA token auto-mounting disabled where not needed
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

[ ] ais-ocp4-cis-accounts-unique-service-account (MEDIUM)
    Evidence File: 05-serviceaccount-controls.txt (Section 5.2)
    Review: Workloads use dedicated service accounts
    Finding: _________________________________________________
    Compliant: [ ] Yes  [ ] No
    Justification: _______________________________________

───────────────────────────────────────────────────────────────
REVIEW SUMMARY
───────────────────────────────────────────────────────────────

Total Controls Reviewed: 22
Compliant: _____
Non-Compliant: _____
Review Completion Date: _____________________

Reviewer: _____________________________ Date: ______________
Security Manager: ______________________ Date: ______________
CISO: _________________________________ Date: ______________

───────────────────────────────────────────────────────────────
NEXT REVIEW SCHEDULED: ___________________________________
───────────────────────────────────────────────────────────────
EOF
    
    print_success "Review checklist generated: ${CHECKLIST_FILE}"
    add_to_summary "✓ 08-REVIEW-CHECKLIST.txt - Manual review checklist template"
}

#################################################################################
# Main Execution
#################################################################################

main() {
    print_info "Starting evidence collection..."
    print_info "Output directory: ${OUTPUT_DIR}"
    echo ""
    
    # Check oc command availability
    if ! command -v oc &> /dev/null; then
        print_error "oc command not found. Please install OpenShift CLI."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! oc whoami &> /dev/null; then
        print_error "Not logged in to OpenShift cluster. Please login first."
        exit 1
    fi
    
    # Collect evidence
    collect_rbac_evidence
    collect_scc_evidence
    collect_namespace_evidence
    collect_secrets_evidence
    collect_serviceaccount_evidence
    collect_compliance_results
    collect_cluster_info
    generate_checklist
    
    # Finalize summary
    echo "" >> "${SUMMARY_FILE}"
    echo "Collection completed at: $(date)" >> "${SUMMARY_FILE}"
    echo "" >> "${SUMMARY_FILE}"
    echo "Next Steps:" >> "${SUMMARY_FILE}"
    echo "1. Review each evidence file" >> "${SUMMARY_FILE}"
    echo "2. Complete the checklist (08-REVIEW-CHECKLIST.txt)" >> "${SUMMARY_FILE}"
    echo "3. Document findings and justifications" >> "${SUMMARY_FILE}"
    echo "4. Obtain required approvals" >> "${SUMMARY_FILE}"
    echo "5. Archive evidence for compliance records" >> "${SUMMARY_FILE}"
    
    # Print summary
    print_section "COLLECTION COMPLETE"
    cat "${SUMMARY_FILE}"
    
    echo ""
    print_success "All evidence files saved to: ${OUTPUT_DIR}"
    print_info "You can now review the evidence and complete the checklist."
    echo ""
    print_info "To create a tarball for archival:"
    echo "  tar -czf ocp4-cis-evidence-${TIMESTAMP}.tar.gz -C /tmp ocp4-cis-manual-evidence-${TIMESTAMP}"
    echo ""
}

# Run main function
main "$@"
