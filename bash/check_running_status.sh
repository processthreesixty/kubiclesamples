#!/bin/bash

# Enable debug mode for the script (prints each command before execution)
set -x

# Variables
RELEASE_NAME=$1     # Helm release name passed as the first argument
NAMESPACE=$2        # Namespace of the Helm release
CURL_URL=$3         # URL to trigger with curl

# Check for required arguments
if [ -z "$RELEASE_NAME" ] || [ -z "$NAMESPACE" ] || [ -z "$CURL_URL" ]; then
    echo "Usage: $0 <release_name> <namespace> <curl_url>"
    exit 1
fi

# Function to check if the Helm release exists and print the status output
check_release_exists() {
    echo "Checking if Helm release $RELEASE_NAME exists in namespace $NAMESPACE..."
    RELEASE_STATUS=$(helm status "$RELEASE_NAME" -n "$NAMESPACE" 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "Helm release $RELEASE_NAME does not exist in namespace $NAMESPACE."
        echo "helm status command output:"
        echo "$RELEASE_STATUS"
        exit 0
    else
        echo "Helm release $RELEASE_NAME exists."
        echo "Helm status output:"
        echo "$RELEASE_STATUS"
    fi
}

# Function to check pod status based on label
check_pods_running() {
    echo "Checking pods for Helm release: $RELEASE_NAME in namespace: $NAMESPACE"
    
    # Get pods associated with the Helm release by label
    echo "Fetching pod list using label: app.kubernetes.io/instance=$RELEASE_NAME"
    PODS=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" -o jsonpath='{.items[*].metadata.name}')

    # Debug: Print the pod list
    echo "Pods found: $PODS"

    if [ -z "$PODS" ]; then
        echo "No pods found for release: $RELEASE_NAME in namespace: $NAMESPACE"
        return 1
    fi

    for POD in $PODS; do
        echo "Checking status of pod: $POD"
        STATUS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        echo "Status of pod $POD: $STATUS"
        if [ "$STATUS" != "Running" ]; then
            echo "Pod $POD is not Running yet (Current status: $STATUS)"
            return 1
        fi
    done

    echo "All pods are in Running state."
    return 0
}

# Function to get the load balancer's external IP or hostname based on label
get_load_balancer_ip() {
    echo "Fetching Load Balancer External IP or Hostname for Helm release: $RELEASE_NAME in namespace: $NAMESPACE"

    # Debug: Check all services in the namespace
    echo "Listing all services in namespace: $NAMESPACE"
    kubectl get svc -n "$NAMESPACE" -o wide

    # Get the external IP or hostname from the service label
    EXTERNAL_IP=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
    EXTERNAL_HOSTNAME=$(kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

    # Ensure either IP or hostname is available
    if [ -z "$EXTERNAL_IP" ] && [ -z "$EXTERNAL_HOSTNAME" ]; then
        echo "Load Balancer External IP or Hostname not available yet for release: $RELEASE_NAME"
        return 1
    fi

    echo "Load Balancer External IP: $EXTERNAL_IP"
    echo "Load Balancer External Hostname: $EXTERNAL_HOSTNAME"
    return 0
}

# Function to check if the external IP or hostname is responding
check_external_address() {
    if [ -n "$EXTERNAL_IP" ]; then
        echo "Checking if Load Balancer IP ($EXTERNAL_IP) is responding..."
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "http://$EXTERNAL_IP")
        if [ "$HTTP_STATUS" -eq 200 ]; then
            echo "Load Balancer IP is responding with HTTP 200."
            return 0
        else
            echo "Load Balancer IP is not responding (HTTP $HTTP_STATUS)."
        fi
    fi

    if [ -n "$EXTERNAL_HOSTNAME" ]; then
        echo "Checking if Load Balancer Hostname ($EXTERNAL_HOSTNAME) is responding..."
        HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "http://$EXTERNAL_HOSTNAME")
        if [ "$HTTP_STATUS" -eq 200 ]; then
            echo "Load Balancer Hostname is responding with HTTP 200."
            return 0
        else
            echo "Load Balancer Hostname is not responding (HTTP $HTTP_STATUS)."
        fi
    fi

    return 1
}

# Check if the release exists
check_release_exists

# Wait for pods to be in Running state and Load Balancer IP/Hostname to be available and responding
while true; do
    echo "Starting check for pods, Load Balancer IP/Hostname, and response from the application..."

    if check_pods_running && get_load_balancer_ip && check_external_address; then
        echo "Triggering curl to URL: $CURL_URL with Load Balancer IP/Hostname in the body"
        curl -X POST -H "Content-Type: application/json" -d "{
            \"loadBalancerIP\": \"$EXTERNAL_IP\",
            \"loadBalancerHostname\": \"$EXTERNAL_HOSTNAME\"
        }" "$CURL_URL"
        exit 0
    fi

    echo "Waiting for pods to be ready, Load Balancer IP/Hostname to be available, and application to respond..."
    sleep 5
done
