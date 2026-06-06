#!/bin/bash

# Configuration
INVOKE_URL="https://fux17srgoh.execute-api.ap-south-2.amazonaws.com/invoke"
DURATION=60  # How long to run the test (seconds)
INTERVAL=2   # Interval between requests (seconds)

echo "----------------------------------------------------------------"
echo "NSP-4-S2-S25App API Reliability & Performance Test"
echo "Endpoint: $INVOKE_URL"
echo "Running for $DURATION seconds with $INTERVAL second intervals..."
echo "----------------------------------------------------------------"

END_TIME=$((SECONDS + DURATION))

while [ $SECONDS -lt $END_TIME ]; do
    echo "[$(date +%H:%M:%S)] Sending request..."
    
    # Send request and capture response + status code
    RESPONSE=$(curl -s -X POST "$INVOKE_URL" \
        -H "Content-Type: application/json" \
        -d '{"prompt":"Tell me a fact about DevOps."}')
    
    # Print formatted response
    echo "Response: $RESPONSE"
    echo "----------------------------------------------------------------"
    
    sleep $INTERVAL
done

echo "Test Complete."
