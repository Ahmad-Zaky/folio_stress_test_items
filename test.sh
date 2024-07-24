#!/bin/bash

# ############################################################################################  # 
#                                                                                               # 
# - we try to mimic different users creating multiple items at the same time,                   # 
#   so we will run multiple batches of post http requests of items in parallel.                 # 
# - 'BATCHES_NO' variable represents number of users runs in parallel.                          # 
# - 'CALL_REQUESTS_LIMIT' variable represents the number of items created for each batch.       # 
# - in defaults() method there are some default varialbes should be filled                      #
#   before running the script.                                                                  # 
# - run test.sh without any arguments to add items under specific holding.                      # 
# - run test.sh cp with 'cp' argument to copy all item ids from items.json to clipboard,        # 
#   which could be used later to remvoe the added items.                                        # 
# - run test.sh rm with 'rm' argument to remove items copied from clipboard to the              # 
#   'UUIDS' array variable.                                                                     # 
#                                                                                               # 
# ############################################################################################  # 

new_file_line() {
    echo -e "" >> $1
}

new_line() {
    echo -e ""
}

new_output_line() {
	echo -e "" >> output.txt
	echo -e "" >> output.txt
}

function call_request() {
    local BARCODE=$1
    local BATCH_NO=$2
    local HOLDING_RECORD_ID=$3

	UUID=`uuidgen`

    # example create item payload json
    local CURL_BODY='{
        "id":"'$UUID'",
        "barcode":"'$BARCODE'",
        "holdingsRecordId": "'$HOLDING_RECORD_ID'",
        "status": {
            "name": "Available"
        },
        "materialType": {
            "id": "1a54b431-2e4f-452d-9cae-9cee66c9a892"
        },
        "itemLevelCallNumber": "DK508.848 .E976 2014",
        "permanentLoanType": {
            "id":"c44898a4-7d6b-4baa-aada-c620f18427bb"
        },
        "discoverySuppress": false,
        "statisticalCodeIdsHolding":[],
        "statisticalCodeIdsItems":[],
        "yearCaption":[null],
        "statisticalCodeIds":[]
    }'

    TIME=$(curl -s -o response.txt -w "%{time_total}" $OKAPI_URL$OKAPI_PATH \
    -H 'accept: application/json' \
    -H 'accept-language: en-US-u-nu-latn' \
    -H 'content-type: application/json' \
    -H 'x-okapi-tenant: '$X_OKAPI_TENANT \
    -H 'x-okapi-url: '$X_OKAPI_URL \
    -H 'x-okapi-token: '$X_OKAPI_TOKEN \
    --data "$CURL_BODY" \
    --compressed)

    RESPONSE=$(cat response.txt) && : > response.txt

	echo $RESPONSE >> output.txt

    echo "$TIME"
}

function call_requests() {
    BATCH_NO=$1
    local HOLDING_RECORD_ID=$2
    BARCODE_STARTER=$BATCH_NO"000000"
    TOTAL_TIME=0.0
    MIN_TIME=9999999999.0
    MAX_TIME=0.0

    echo "Call Requests batch #$BATCH_NO"

    for i in $(seq 1 $CALL_REQUESTS_LIMIT)
    do 
        local BARCODE=$((BARCODE_STARTER + $i))

        local TIME=$(call_request $BARCODE $BATCH_NO $HOLDING_RECORD_ID)

        echo "New Item with barcode $BARCODE for batch #$BATCH_NO TOOK ($TIME sec) " >> items_time.txt

        # Update min and max time if necessary
        if (( $(echo "$TIME < $MIN_TIME" | bc -l) )); then
            MIN_TIME=$TIME
        fi

        if (( $(echo "$TIME > $MAX_TIME" | bc -l) )); then
            MAX_TIME=$TIME
        fi

        TOTAL_TIME=$(echo "$TOTAL_TIME" + "$TIME" | bc)
    done

    calc_stats
}

calc_stats() {
    new_file_line items_stats.txt

    echo "Total time for batch #$BATCH_NO: ($TOTAL_TIME sec)" >> items_stats.txt
    echo "Min $MIN_TIME s for $CALL_REQUESTS_LIMIT items Batch #$BATCH_NO" >> items_stats.txt
    AVG_TIME=$(echo "scale=6; $TOTAL_TIME/$CALL_REQUESTS_LIMIT" | bc)
    echo "Averaged $AVG_TIME sec for $CALL_REQUESTS_LIMIT items Batch #$BATCH_NO" >> items_stats.txt
    echo "Max $MAX_TIME sec for $CALL_REQUESTS_LIMIT items Batch #$BATCH_NO" >> items_stats.txt

    new_file_line  items_stats.txt
}

remove_item() {
    local UUID=$1

    curl $OKAPI_URL$DELETE_OKAPI_PATH$UUID \
        -X 'DELETE' \
        -H 'accept: text/plain' \
        -H 'accept-language: en-US-u-nu-latn' \
        -H 'content-type: application/json' \
        -H 'x-okapi-tenant: '$X_OKAPI_TENANT \
        -H 'x-okapi-token: '$X_OKAPI_TOKEN \
        --compressed
}

remove_items() {
    INDEX=0
    # Loop through the UUIDs
    for UUID in "${UUIDS[@]}"; do
        ((INDEX++))
        echo "Remove Item with UUID: $UUID"

        remove_item $UUID &
        if [ $((INDEX % 100)) -eq 0 ]; then
            echo "Waiting for last $INDEX items to be removed first"

            wait
            sleep 5
        fi
    done
}

clear_logs() {
    : > output.txt
    : > response.txt
    : > items_time.txt
    : > items_stats.txt
}

load_item_batches() {
    clear_logs

    for i in $(seq 1 $BATCHES_NO)
    do
        HOLDING_INDEX=$(( $i % $HOLDINGS_SIZE ))
        HOLDING_RECORD_ID="${HOLDINGS[$HOLDING_INDEX]}" 

        call_requests $i $HOLDING_RECORD_ID &
    done
}

process_args() {
    if [[ $1 == "cp" ]]; then
        jq .items[].id items.json | xclip -selection clipboard

        exit 0
    fi

    if [[ $1 == "rm" ]]; then
        remove_items

        exit 0
    fi
}

defaults() {
    X_OKAPI_TENANT="<tenant>" # ex: "diku"
    X_OKAPI_TOKEN="<token>" # ex: "eyJhbGciOiJIUzI1NiJ9.eyJz..."
    X_OKAPI_URL="http://okapi" # ex: "https://okapi.example.com"
    OKAPI_PATH="/inventory/items" # ex: "/inventory/items"
    DELETE_OKAPI_PATH="/inventory/items/" # ex: "/inventory/items/"
    OKAPI_URL="http://okapi" # ex: "https://okapi.example.com" or "http://localhost:8081" 

    # Define a list of item UUIDs to be removed
    UUIDS=(
        "cc3b1520-72db-4ef6-b0e9-b50254d83f5e"
        "64b83084-c948-4582-a4ad-6073ff2d8660"
        "1a746b71-a6a4-447e-8bb0-2b004612805b"
    )

    HOLDINGS=(
        "cbb68ab1-cf3d-4650-bdca-2dda3f788ff4"
    )
    HOLDINGS_SIZE=${#HOLDINGS[@]}

    BATCHES_NO=1
    CALL_REQUESTS_LIMIT=1
    if ! [[ -z "$1" ]] && ! [[ -z "$2" ]]; then
        BATCHES_NO=$1
        CALL_REQUESTS_LIMIT=$2
    fi
}

defaults $*
process_args $1
load_item_batches
