#!/bin/bash

# Variables
RELEASE_NAME=$1     # Helm release name passed as the first argument
NAMESPACE=$2        # Namespace of the Helm release
CURL_URL=$3         # URL to trigger with curl

# Check for required arguments
if [ -z "$RELEASE_NAME" ] || [ -z "$NAMESPACE" ] || [ -z "$CURL_URL" ]; then
    echo "Usage: $0 <release_name> <namespace> <curl_url>"
    exit 1
fi

# Function to check pod status based on annotation
check_pods_running() {
    echo "Checking pods for Helm release: $RELEASE_NAME in namespace: $NAMESPACE"
    
    # Get pods associated with the Helm release by annotation
    PODS=$(kubectl get pods -n "$NAMESPACE" -o json | jq -r ".items[] | select(.metadata.annotations[\"meta.helm.sh/release-name\"]==\"$RELEASE_NAME\") | .metadata.name")

    if [ -z "$PODS" ]; then
        echo "No pods found for release: $RELEASE_NAME"
        return 1
    fi

    for POD in $PODS; do
        STATUS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        if [ "$STATUS" != "Running" ]; then
            echo "Pod $POD is not Running yet (Current status: $STATUS)"
            return 1
        fi
    done

    echo "All pods are in Running state."
    return 0
}

# Function to get the load balancer's external IP based on annotation
get_load_balancer_ip() {
    echo "Fetching Load Balancer External IP for Helm release: $RELEASE_NAME"
    EXTERNAL_IP=$(kubectl get svc -n "$NAMESPACE" -o json | jq -r ".items[] | select(.metadata.annotations[\"meta.helm.sh/release-name\"]==\"$RELEASE_NAME\") | .status.loadBalancer.ingress[0].ip")
    if [ -z "$EXTERNAL_IP" ]; then
        echo "Load Balancer External IP not available yet."
        return 1
    fi
    echo "Load Balancer External IP: $EXTERNAL_IP"
    return 0
}

# Wait for pods to be in Running state and Load Balancer IP to be available
while true; do
    if check_pods_running && get_load_balancer_ip; then
        echo "Triggering curl to URL: $CURL_URL with Load Balancer IP in the body"
        curl -X POST -H "Content-Type: application/json" -d "{\"loadBalancerIP\": \"$EXTERNAL_IP\"}" "$CURL_URL"
        exit 0
    fi
    echo "Waiting for pods to be ready and Load Balancer IP to be available..."
    sleep 5
done
