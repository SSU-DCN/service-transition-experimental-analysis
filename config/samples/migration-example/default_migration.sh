#!/bin/bash

# Namespace to monitor
NAMESPACE="default"

# Template for creating a new Pod
POD_TEMPLATE=$(cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: __POD_NAME__
  labels:
    app: __APP_LABEL__
spec:
  containers:
  - name: __CONTAINER_NAME__
    image: __CONTAINER_IMAGE__
    ports:
__CONTAINER_PORTS__
    args: 
__CONTAINER_ARGS__
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - __TARGET_NODE__
EOF
)

echo "Monitoring cluster for node drain events... (Press Ctrl+C to stop)"

# Trap SIGINT to handle Ctrl+C gracefully
trap "echo 'Exiting script...'; exit" SIGINT

while true; do
  # Find all drained nodes (unschedulable)
  DRAINED_NODES=$(kubectl get nodes -o jsonpath='{.items[?(@.spec.unschedulable==true)].metadata.name}')

  if [[ -n "$DRAINED_NODES" ]]; then
    echo "Detected the following drained nodes: $DRAINED_NODES"

    for SOURCE_NODE in $DRAINED_NODES; do
      echo "Processing pods on drained node $SOURCE_NODE..."

      # Find a target node
      TARGET_NODE=$(kubectl get nodes --field-selector spec.unschedulable!=true -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "^$SOURCE_NODE$" | grep -v "^master$" | head -n 1)

      if [[ -z "$TARGET_NODE" ]]; then
        echo "No available target nodes to move pods."
        continue
      fi

      echo "Target node for pods is $TARGET_NODE."

      # Get pods on the drained node
      PODS=$(kubectl get pods -n $NAMESPACE --field-selector spec.nodeName=$SOURCE_NODE -o jsonpath='{.items[*].metadata.name}')

      if [[ -z "$PODS" ]]; then
        echo "No standalone pods to process on $SOURCE_NODE."
        continue
      fi

      for POD_NAME in $PODS; do
        echo "Processing pod $POD_NAME in namespace $NAMESPACE"

        # Fetch pod details
        POD_DETAILS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o json)

        # Extract necessary fields from the current Pod
        APP_LABEL=$(echo "$POD_DETAILS" | jq -r '.metadata.labels.app')
        CONTAINER_NAME=$(echo "$POD_DETAILS" | jq -r '.spec.containers[0].name')
        CONTAINER_IMAGE=$(echo "$POD_DETAILS" | jq -r '.spec.containers[0].image')
        CONTAINER_PORTS=$(echo "$POD_DETAILS" | jq -r '.spec.containers[0].ports | .[] | "- containerPort: \(.containerPort)\n  protocol: \(.protocol)"')
        CONTAINER_ARGS=$(echo "$POD_DETAILS" | jq -r '.spec.containers[0].args | .[] | "  - \(.)"')


        # Generate a new Pod spec using the template
        NEW_POD_SPEC=$(echo "$POD_TEMPLATE" | sed \
         -e "s|__POD_NAME__|$(printf '%s' "$POD_NAME" | sed 's/[&/\]/\\&/g')|" \
	 -e "s|__APP_LABEL__|$(printf '%s' "$APP_LABEL" | sed 's/[&/\]/\\&/g')|" \
         -e "s|__CONTAINER_NAME__|$(printf '%s' "$CONTAINER_NAME" | sed 's/[&/\]/\\&/g')|" \
         -e "s|__CONTAINER_IMAGE__|$(printf '%s' "$CONTAINER_IMAGE" | sed 's/[&/\]/\\&/g')|" \
         -e "s|__CONTAINER_PORTS__|$CONTAINER_PORTS|" \
         -e "s|__CONTAINER_ARGS__|$CONTAINER_ARGS|" \
         -e "s|__TARGET_NODE__|$(printf '%s' "$TARGET_NODE" | sed 's/[&/\]/\\&/g')|")

        # Save the new Pod spec to a file
        echo "$NEW_POD_SPEC" > /tmp/$POD_NAME.yaml

	# Debugging: Verify the generated YAML
        echo "Generated YAML:"
        cat /tmp/$POD_NAME.yaml

        # Delete the old Pod
        kubectl delete pod $POD_NAME -n $NAMESPACE

        # Apply the new Pod spec
        if kubectl apply -f /tmp/$POD_NAME.yaml; then
          echo "Successfully recreated pod $POD_NAME on target node $TARGET_NODE."
        else
          echo "[ERROR] Failed to recreate pod $POD_NAME. Check /tmp/$POD_NAME.yaml for details."
        fi
      done
    done
  fi

  # Wait before checking again
done

