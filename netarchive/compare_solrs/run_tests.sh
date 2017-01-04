#!/bin/bash

#
# Executes performance tests on previously created shards
#

pushd ${BASH_SOURCE%/*} > /dev/null
source compare.conf
source ../../solrcloud/general.conf
source cloud_control.sh

: ${TEST_SOLRS:="$@"}
: ${TEST_SOLRS:="$VERSIONS"}
: ${TEST_DESTS:="ssd:/mnt/index/performance.tmp 7200rpm:/mnt/bulk/performance.tmp"}
: ${TEST_SHARDS:="1 2"}
: ${TEST_SEGMENTEDS:="false true"}
: ${TEST_RUNS:="2"}
: ${TEST_FACETS:="none vanilla sparse"}
: ${TEST_DEST:=`date +%Y%m%d-%H%M`}

: ${TEST_CLOUD_REUSE:="true"}

usage() {
    echo "Usage: ./run_tests.sh source_version+"
    echo "Available versions: `echo \"$VERSIONS\" | sed 's/ / | /g'`"
    exit $1
}

setup() {
    local TEST_DEST_DESIGNATION=`echo $TEST_DEST | cut -d: -f1`
    local TEST_DEST_FOLDER=`echo $TEST_DEST | cut -d: -f2`
    CLOUD="${TEST_DEST_FOLDER}/${TEST_SOLR}/${TEST_SHARD}_shards/segmented_${TEST_SEGMENTED}"

    echo "  - Setting up Solr $TEST_SOLR with $TEST_SHARD shards and segmented=$TEST_SEGMENTED at $TEST_DEST_FOLDER ($TEST_DEST_DESIGNATION)"

    if [ -d $CLOUD ]; then
        if [ "true" == "$TEST_CLOUD_REUSE" ]; then
            echo "    - Skipping cloud setup at a previous cloud was found at ${CLOUD}"
            return
        fi
    fi

    echo "    - Installing cloud at ${CLOUD}"
    fresh_cloud $TEST_SOLR
    ( . $CC/cloud_start.sh $TEST_SOLR )
    local SRC=$MASTER_DEST/$TEST_SOLR
    echo "   - Uploading config from $SRC/conf"
    ( . $CC/cloud_sync.sh $TEST_SOLR $SRC/conf/ cremas_conf )
    ( . $CC/cloud_stop.sh $TEST_SOLR )

    echo "    - Copying shards into Solr folder"
    if [ "." == ".`echo \" 5.5.3 6.3.0 trunk trunk-7521 \" | grep \" $TEST_SOLR \"`" ]; then
        pushd $CLOUD/$TEST_SOLR/solr1/example/solr > /dev/null
    else
        pushd $CLOUD/$TEST_SOLR/solr1/server/solr > /dev/null
    fi
        
    rm -rf cremas_*/
    for S in `seq 1 $TEST_SHARD`; do
        local LSRC=$SRC/${TEST_SHARD}/cremas_shard${S}_replica1
        if [ ! -d $LSRC/data/index ]; then
            >&2 echo "Error: Want to copy, but the end-point does not exist: $LSRC/data/index"
            exit 19
        fi
            
        cp -r $LSRC cremas_shard${S}_replica1
    done
    popd > /dev/null # solr

    echo "    - Starting cloud with shards"
    ( . $CC/cloud_start.sh $TEST_SOLR )

    if [ ! "true" == "$TEST_SEGMENTED" ]; then
        echo "    - Skipping segmentation"
    else
        echo "    - Performing segmentation"
        force_segmentation
    fi
}
teardown() {
    local TEST_DEST_DESIGNATION=`echo $TEST_DEST | cut -d: -f1`
    local TEST_DEST_FOLDER=`echo $TEST_DEST | cut -d: -f2`
    CLOUD="${TEST_DEST_FOLDER}/${TEST_SOLR}/${TEST_SHARD}_shards/segmented_${TEST_SEGMENTED}"

    echo "  - Shutting down cloud at $CLOUD"
    ( . $CC/cloud_stop.sh $TEST_SOLR )

    if [ "true" == "$TEST_CLOUD_REUSE" ]; then
        echo "  - Skipping removal of cloud as reuse=true"
        return
    fi
    echo "  - Removing cloud at $CLOUD"
    pushd ${TEST_DEST_FOLDER} > /dev/null
    rm -r "${TEST_SOLR}/${TEST_SHARD}_shards/segmented_${TEST_SEGMENTED}"
    popd > /dev/null
}


run_tests() {
    local R="${TEST_FACETS//[^ ]}"
    local RC="${#R}"
    
    local TOTAL=$(( TEST_RUNS * (RC+1) ))
    local RUN=1
    for TEST_RUN in `seq 1 $TEST_RUNS`; do
        for TEST_FACET in $TEST_FACETS; do
            echo "    - Running test $RUN/$TOTAL with facet=$TEST_FACET"
            # TODO: Check that this is properly permissioned to be executed by user
            sudo ../../solrcloud/drop_cache.sh
            RUN=$(( RUN+1 ))
        done
    done
}

# Input: Version
main() {
    echo "- Starting tests `date +%Y%m%d-%H%M`"
    for TEST_SOLR in $TEST_SOLRS; do
        if [ "." == ".`echo \" $VERSIONS \" | grep \" $TEST_SOLR \"`" ]; then
            >&2 echo "Unsupported Solr version: $TEST_SOLRS"
            usage 2
        fi
    done

    for TEST_DEST in $TEST_DESTS; do
        for TEST_SOLR in $TEST_SOLRS; do
            for TEST_SHARD in $TEST_SHARDS; do
                for TEST_SEGMENTED in $TEST_SEGMENTEDS; do
                    setup
                    run_tests
                    teardown
                    exit
                done
            done
        done
    done
    echo "- Done `date +%Y%m%d-%H%M`"
}
main
