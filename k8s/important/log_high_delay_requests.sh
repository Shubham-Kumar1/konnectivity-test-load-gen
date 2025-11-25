#!/bin/bash

# Define the bucket ranges for latency (in milliseconds)
BUCKETS=(0 1000 5000 10000 20000 50000 100000)

# Function to process a single log file and calculate latency distribution
process_log() {
    local log_file=$1
    local pod_name=$2
    declare -A BUCKET_COUNTS

    # Initialize bucket counts
    for bucket in "${BUCKETS[@]}"; do
        BUCKET_COUNTS["$bucket"]=0
    done

    # Check if the log file exists
    if [[ ! -f "$log_file" ]]; then
        echo "Log file $log_file not found!"
        return
    fi

    # Read the log file line by line
    while read -r line; do
        # Check if the line contains latency data (processingTimeMs)
        if [[ "$line" =~ processingTimeMs=([0-9]+) ]]; then
            latency_ms="${BASH_REMATCH[1]}"

            # Update bucket counts based on the latency value
            for bucket in "${BUCKETS[@]}"; do
                if [[ $latency_ms -le $bucket ]]; then
                    BUCKET_COUNTS["$bucket"]=$((BUCKET_COUNTS["$bucket"] + 1))
                    break
                fi
            done
        fi
    done < "$log_file"

    # Display the latency distribution for the pod
    echo "Latency Distribution for Pod $pod_name:"
    for bucket in "${BUCKETS[@]}"; do
        echo "  <= $bucket ms: ${BUCKET_COUNTS[$bucket]} requests"
    done
    echo ""
}

# Process the logs of both pods and generate separate reports
process_log "app2-67c77784ff-6mjvf-app2.log" "app2-67c77784ff-6mjvf"
process_log "app2-67c77784ff-fmfs-app2.log" "app2-67c77784ff-fmfs"
process_log "app2-67c77784ff-fmfs-app2.log" "app2-67c77784ff-fmfs"
process_log "app2-67c77784ff-fmfs-app2.log" "app2-67c77784ff-fmfs"  