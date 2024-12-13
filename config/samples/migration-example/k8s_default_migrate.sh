#!/bin/bash

# Namespace to monitor
NAMESPACE="default"

echo "Monitoring cluster for node drain events... (Press Ctrl+C to stop)"

# Trap SIGINT to handle Ctrl+C gracefully
trap "echo 'Exiting script...'; exit" SIGINT

# Infinite loop to keep the script running
while true; do
  # Find all drained nodes (unschedulable)
  DRAINED_NODES=$(kubectl get nodes -o jsonpath='{.items[?(@.spec.unschedulable==true)].metadata.name}')

  if [[ -n "$DRAINED_NODES" ]]; then
    echo "Detected the following drained nodes: $DRAINED_NODES"

    # Process each drained node
    for SOURCE_NODE in $DRAINED_NODES; do
      echo "Processing pods on drained node $SOURCE_NODE..."

      # Get all schedulable nodes excluding the drained node
      TARGET_NODE=$(kubectl get nodes --field-selector spec.unschedulable!=true -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v "^$SOURCE_NODE$" | grep -v "^master$" | head -n 1)

      if [[ -z "$TARGET_NODE" ]]; then
        echo "No available target nodes to move pods."
        continue
      fi

      echo "Target node for pods is $TARGET_NODE."

      # Get all standalone pods running on the drained node
      PODS=$(kubectl get pods -n $NAMESPACE --field-selector spec.nodeName=$SOURCE_NODE -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

      if [[ -z "$PODS" ]]; then
        echo "No standalone pods to process on $SOURCE_NODE."
        continue
      fi

      for POD_NAME in $PODS; do
        echo "Processing pod $POD_NAME in namespace $NAMESPACE"

        # Export pod YAML
        kubectl get pod $POD_NAME -n $NAMESPACE -o yaml > /tmp/$POD_NAME.yaml

        # Remove nodeName and other ephemeral fields
        sed -i '/nodeName:/d' /tmp/$POD_NAME.yaml
	sed -i '/nodeSelector:/,/^[^ ]/d' /tmp/$POD_NAME.yaml
        sed -i '/status:/,$d' /tmp/$POD_NAME.yaml
        sed -i '/conditions:/,/^[^ ]/d' /tmp/$POD_NAME.yaml
        sed -i '/^  phase:/d' /tmp/$POD_NAME.yaml
        sed -i '/^  hostIP:/d' /tmp/$POD_NAME.yaml
        sed -i '/^  podIP:/d' /tmp/$POD_NAME.yaml
        sed -i '/^  qosClass:/d' /tmp/$POD_NAME.yaml
	sed -i '/^  serviceAccountName:/d' /tmp/$POD_NAME.yaml
	sed -i '/^  volumes:/,/^[^ ]/d' /tmp/$POD_NAME.yaml
	sed -i '/^  volumeMounts:/,/^[^ ]/d' /tmp/$POD_NAME.yaml
	sed -i '/default-token/d' /tmp/$POD_NAME.yaml

	# Ensure volumeMounts and volumes are retained
	VOLUME_MOUNTS=$(grep -A 10 'volumeMounts:' /tmp/$POD_NAME.yaml)
        VOLUMES=$(grep -A 10 'volumes:' /tmp/$POD_NAME.yaml)

	if [[ -n "$VOLUME_MOUNTS" && -n "$VOLUMES" ]]; then
		echo "[INFO] Retaining volumes and volumeMounts for Pod $POD_NAME."
	else
		echo "[WARNING] Pod $POD_NAME has incomplete volumes or volumeMounts. Check manually."
	fi



        # Add node affinity for the target node
        cat <<EOF >> /tmp/$POD_NAME.yaml
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
            - $TARGET_NODE
EOF

        # Delete the pod
        kubectl delete pod $POD_NAME -n $NAMESPACE

        # Recreate the pod on the target node
        kubectl apply -f /tmp/$POD_NAME.yaml  --validate=false

        done
      done
  fi

  # Wait before checking again
  sleep 1
done

