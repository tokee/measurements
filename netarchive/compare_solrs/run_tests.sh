#!/bin/bash

#
# Executes performance tests on previously created shards
#

# TODO
# Make this resumable, by skipping tests where there is already a folder

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
: ${TEST_RESULT_DEST:=`pwd`/`date +%Y%m%d-%H%M`}

: ${TEST_CLOUD_REUSE:="true"}
: ${SOLR_OUT:="solr.out"}

usage() {
    echo "Usage: ./run_tests.sh source_version+"
    echo "Available versions: `echo \"$VERSIONS\" | sed 's/ / | /g'`"
    exit $1
}

setup() {
    local TEST_DEST_DESIGNATION=`echo $TEST_DEST | cut -d: -f1`
    local TEST_DEST_FOLDER=`echo $TEST_DEST | cut -d: -f2`
    CLOUD="${TEST_DEST_FOLDER}/${TEST_SOLR}/shards=${TEST_SHARD}_segmented=${TEST_SEGMENTED}"

    echo "  - Setting up Solr $TEST_SOLR with $TEST_SHARD shards and segmented=$TEST_SEGMENTED at $TEST_DEST_FOLDER ($TEST_DEST_DESIGNATION)"

    if [ -d $CLOUD ]; then
        if [ "true" == "$TEST_CLOUD_REUSE" ]; then
            echo "    - Skipping cloud setup at a previous cloud was found at ${CLOUD}"
            return
        fi
    fi

    echo "    - Installing cloud at ${CLOUD}"
    fresh_cloud $TEST_SOLR
    SOLR_MEM=$TEST_MEM
    ( . $CC/cloud_start.sh $TEST_SOLR >> $SOLR_OUT )
    local SRC=$MASTER_DEST/`echo $TEST_SOLR | sed 's/\(.*\)-sparse/\1/'`
    echo "   - Uploading config from $SRC/conf"
    ( . $CC/cloud_sync.sh $TEST_SOLR $SRC/conf/ cremas_conf >> $SOLR_OUT )
    ( . $CC/cloud_stop.sh $TEST_SOLR >> $SOLR_OUT )

    echo "    - Copying $TEST_SHARD shards into Solr folder"
    if [ "." == ".`echo \" 5.5.3 6.3.0 trunk trunk-7521 \" | grep \" $TEST_SOLR \"`" ]; then
        pushd $CLOUD/$TEST_SOLR/solr1/example/solr > /dev/null
    else
        pushd $CLOUD/$TEST_SOLR/solr1/server/solr > /dev/null
    fi
        
    rm -rf cremas_*/
    for S in `seq 1 $TEST_SHARD`; do
        local LSRC=$SRC/${TEST_SHARD}/cremas_shard${S}_replica1
        if [ ! -d $LSRC/data/index ]; then
            >&2 echo "Error: Source shards needed for testing does not exist: $LSRC/data/index"
            exit 19
        fi
            
        echo "      - exec> cp -r $LSRC cremas_shard${S}_replica1"
        cp -r $LSRC cremas_shard${S}_replica1
    done
    popd > /dev/null # solr

    echo "    - Starting cloud with shards"
    ( . $CC/cloud_start.sh $TEST_SOLR >> $SOLR_OUT )
    verify_cloud
    
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
    CLOUD="${TEST_DEST_FOLDER}/${TEST_SOLR}/shards=${TEST_SHARD}_segmented=${TEST_SEGMENTED}"

    echo "  - Shutting down cloud at $CLOUD"
    ( . $CC/cloud_stop.sh $TEST_SOLR >> $SOLR_OUT )

    if [ "true" == "$TEST_CLOUD_REUSE" ]; then
        echo "  - Skipping removal of cloud as reuse=true"
        return
    fi
    echo "  - Removing cloud at $CLOUD"
    pushd ${TEST_DEST_FOLDER} > /dev/null
    rm -r "${TEST_SOLR}/shards=${TEST_SHARD}_segmented=${TEST_SEGMENTED}"
    popd > /dev/null
}


run_tests() {
    local R="${TEST_FACETS//[^ ]}"
    local RC="${#R}"
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="http://$HOST:$SOLR_BASE_PORT"}
#    : ${SOLR:="http://$HOST:$SOLR_BASE_PORT/solr/cremas"}

    local TOTAL=$(( TEST_RUNS * (RC+1) ))
    local RUN=1
    for TEST_RUN in `seq 1 $TEST_RUNS`; do
        for TEST_FACET in $TEST_FACETS; do
            # TODO: Check that this is properly permissioned to be executed by user
            if [ "vanilla" == "$TEST_FACET" ]; then
                FACET=true
                SPARSE=false
            elif [ "sparse" == "$TEST_FACET" ]; then
                FACET=true
                SPARSE=true
            else
                FACET=false
            fi
            local TEST_DEST_DESIGNATION=`echo $TEST_DEST | cut -d: -f1`
            local TEST_DEST_FOLDER=`echo $TEST_DEST | cut -d: -f2`
            TESTQUERIES=${TEST_QUERIES}
            local RESULT_DEST=${TEST_RESULT_DEST}/${TEST_DEST_DESIGNATION}/${TEST_SOLR}/shards=${TEST_SHARD}_segmented=${TEST_SEGMENTED}_facet=${TEST_FACET}_run=${TEST_RUN} 
            if [ -d $RESULT_DEST ]; then
                echo "    - Skipping test $RUN/$TOTAL with facet=$TEST_FACET as result folder already exists: $RESULT_DEST"
                continue
            fi
            echo "    - Running test $RUN/$TOTAL with facet=$TEST_FACET"
                
            sudo ../../solrcloud/drop_cache.sh
            ( . ../artificial_queries/run_tests.sh $RESULT_DEST )
            RUN=$(( RUN+1 ))
        done
    done
}
count_missing() {
    local MISSING=0
    for TEST_RUN in `seq 1 $TEST_RUNS`; do
        for TEST_FACET in $TEST_FACETS; do
            # TODO: Check that this is properly permissioned to be executed by user
            local TEST_DEST_DESIGNATION=`echo $TEST_DEST | cut -d: -f1`
            local RESULT_DEST=${TEST_RESULT_DEST}/${TEST_DEST_DESIGNATION}/${TEST_SOLR}/shards=${TEST_SHARD}_segmented=${TEST_SEGMENTED}_facet=${TEST_FACET}_run=${TEST_RUN} 
            if [ ! -d $RESULT_DEST ]; then
                local MISSING=$(( MISSING+1))
            fi
        done
    done
    echo $MISSING
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
                    if [ `count_missing` -eq 0 ]; then
                        echo "  - Skipping tests of Solr $TEST_SOLR with $TEST_SHARD shards and segmented=$TEST_SEGMENTED as all tests has already been performed"
                    else
                        echo "  - Running tests of Solr $TEST_SOLR with $TEST_SHARD shards and segmented=$TEST_SEGMENTED"
                        setup
                        run_tests
                        teardown
                    fi
                done
            done
        done
    done
    echo "- Done `date +%Y%m%d-%H%M`"
}
main
