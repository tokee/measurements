#!/bin/bash

: ${OPTIMIZEDS:="false true"}
: ${STORAGES:="ssd spinning"}
: ${OPTIMIZED_SEGMENTS_POSTFIX:=""}

: ${SOLR_VERSIONS:="4.10.4-sparse 6.6.1"}
: ${SHARDSS:="4 2 1"}

: ${FACET_LIMITS:="25 100"}
: ${FACETSS:="5 6"} # Valid: 5 6
: ${THREADSS:="1 2 4"}
: ${FACET_MODES:="none skip facet solr"}
: ${HLS:="false"}

for OPTIMIZED in $OPTIMIZEDS; do
    for STORAGE in $STORAGES; do
        if [[ "ssd" == "$STORAGE" ]]; then
            CLOUD_ROOT="/mnt/index/np"
        elif [[ "spinning" == "$STORAGE" ]]; then
            CLOUD_ROOT="/mnt/bulk/np"
        else
            >&2 echo "Error: STORAGE '$STORAGE' is unsupported"
            exit 4
        fi
        if [[ "true" == "$OPTIMIZED" ]]; then
            CLOUD_ROOT="${CLOUD_ROOT}/optimized${OPTIMIZED_SEGMENTS_POSTFIX}"
        elif [[ "false" == "$OPTIMIZED" ]]; then
            CLOUD_ROOT="${CLOUD_ROOT}"
        else
            >&2 echo "Error: OPTIMIZED '$OPTIMIZED' is unsupported"
            exit 4
        fi
        
        for SOLR_VERSION in $SOLR_VERSIONS; do
            for SHARDS in $SHARDSS; do
                COLLECTION=net_${SHARDS}s
                CLOUD=${CLOUD_ROOT}/${SHARDS}shards
                echo "Starting up solr=$SOLR_VERSION and cloud=$CLOUD"
                . ../cloud_start.sh $SOLR_VERSION
                sleep 20
                HITS=$( ../cloud_verify.sh $SOLR_VERSION "net_${SHARDS}s" )
                if [[ ".$HITS" == ".na" || "$HITS" -eq "0" ]]; then
                    >&2 echo "Unable to get hits from $SOLR_VERSION and cloud=$CLOUD"
                else
                    DEST="shards=${SHARDS}_solr=${SOLR_VERSION}_$(date +%Y%m%d-%H%M)"
                    echo "Running test $SOLR_VERSION with cloud=$CLOUD and total hits=$HITS"
                    . ./measure_solr.sh
                fi
                
                echo "Shutting down $SOLR_VERSION in cloud=$CLOUD"
                . ../cloud_stop.sh $SOLR_VERSION
            done
        done
    done
done
echo "Finished all tests $(date +%Y%m%d-%H%M)"
