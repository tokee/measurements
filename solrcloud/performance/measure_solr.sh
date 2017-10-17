#!/bin/bash

# Tests the speed for different memory configurations on a local Solr instance

# Requires the folder dict/ with sample queries

# TODO: grouping
# TODO: Log output from free, /proc/cpu and similar basic system observations

if [[ ".$CONFIG" != "." ]]; then
    echo "Sourcing custom config $CONFIG"
    source "$CONFIG"
fi
if [[ -s "measure_solr.conf" ]]; then
    echo "Sourcing config measure_solr.conf"
    source "measure_solr.conf"
fi

: ${COLLECTION:="collection1"}

# Output only
: ${SHARDS:="NA"}
: ${OPTIMISED:="NA"}
: ${SOLR_VERSION:="NA"}
: ${STORAGE:="NA"} # spin /ssd

# Count from this
: ${TERM_SOURCE:="0"}

# Rarely changed
: ${SERVER:="localhost"}
: ${SOLRPATH:="solr"}
: ${PORT:="9010"}
: ${SECONDS:="600"}
: ${TIMEOUT:=$((SECONDS+20))}
: ${HANDLER:="select"}
#HANDLER:=edismax
: ${MAX_QUERIES:="1000"}
: ${OP:=""}
: ${ROWS:="10"}

# Tests to run
: ${RUNS:="2"}
: ${FACET_LIMITS:="25"}
: ${FACETSS:="5 6"} # Valid: 5 6
: ${THREADSS:="1 2 4"}
: ${FACET_MODES:="none skip sparse solr"}
: ${HLS:="true false"}

: ${DEST:="test_$(date +%Y%m%d-%H%M)"}

FACETS5="facet=true&facet.field=host&facet.field=content_type_norm&facet.field=public_suffix&facet.field=crawl_year&facet.field=domain"
FACETS6="facet=true&facet.field=url&facet.field=host&facet.field=content_type_norm&facet.field=public_suffix&facet.field=crawl_year&facet.field=domain"

CALL_BASE="http://$SERVER:$PORT/$SOLRPATH/$COLLECTION/$HANDLER?wt=json&indent=true&fl=id,url,host,domain,server,content_type_served,score,last_modified,content_type_tika,content_language&rowd=${ROWS}&facet.sparse.fallbacktobase=false&facet.mincount=1&facet.sparse.maxmincount=0"

: ${SPARSE_MINTAGS:="100000"}
: ${SPARSE_FRACTION:="0.08"}

export THIS_SCRIPT=$(basename $0)
mkdir -p "$DEST"

export SECONDS
export TIMEOUT
export MAX_LOOPS
export CACHE
export OP

export SPARSE_MINTAGS
export SPARSE_FRACTION
INITIAL_TERM_SOURCE=$TERM_SOURCE

check_parameters() {
    if [[ "$SHARD" == "NA" || "$OPTIMIZED" == "NA" || "$SOLR_VERSION" == "NA" || "$STORAGE" == "NA" ]]; then
        >&2 echo "Error: The following vars needs to be set: SHARDS($SHARDS), OPTIMIZED($OPTIMIZED), SOLR_VERSION($SOLR_VERSION), STORAGE($STORAGE)"
        exit 4
    fi
}

dump_options() {
    for VAL in $( cat "${BASH_SOURCE}" | grep -o ': ${[A-Z_]*:=' | grep -o '[A-Z_]*'); do
        echo ": \${$VAL:=\"$(eval echo '$'$VAL)\"}"
    done
}

# Input: URL query outfile (can be shared as appending is synchronized with flock)
# Output: httptimems hits query
solr_request() {
    local QUERY=$(echo "$1" | sed 's/%2B/+/g')
    
    #    local QUERY=$(echo "$1" | sed "s/ / $OP /g")
    #local QUERY=$( echo "$RAW_QUERY" | sed -e 's/æ/%C3%A6/g' -e 's/Æ/%C3%86/g' -e 's/ø/%C3%B8/g' -e 's/Ø/%C3%98/g' -e 's/å/%C3%A5/g' -e 's/Å/%C3%85/g' -e 's/é/%C3%A9/g' )
    #local URL="$CURRENT_BASE&q=$(echo "$QUERY" | tr ' ' '+')"
    local URL="$CURRENT_BASE"
    local S=$(date +%s%N)
    local RESULT=$(curl -s --get --data-urlencode "q=$QUERY" "$URL")
    local E=$(date +%s%N)
    local MS=$(( (E-S)/1000000 ))
    local HITS=$( echo "$RESULT" | jq '.response.numFound' )
    if [[ "null" == "$HITS" || "." == ".$HITS" ]]; then
        >&2 echo "Got null as hits - this should not happen while calling ${URL}&q=${QUERY}"
        return
    fi
    #echo "$RESULT"
    #echo "$URL&q=$QUERY"
    #    echo "jjj $RESULT"
    #echo "ms=$MS hits=$HITS terms=$QUERY"
    if [[ "$HITS" -ne "0" ]]; then
        local QC=$( echo "$QUERY" | sed 's/%2B/+/g' )
        flock -w 2 200 echo "$MS $HITS $QC" >> $OUT_LOG
        flock -w 2 201 echo "$URL&q=$QUERY"$'\n'"$RESULT" >> $OUT_LOG_FULL
    else
        >&2 echo "Error: 0 hits for call"
        >&2 echo "curl -s --get --data-urlencode \"q=$QUERY\" \"$URL\""
    fi
}
export -f solr_request

run_tests() {
    T=$(mktemp)
    200>$T # Used by flock
    T_FULL=$(mktemp)
    201>$T_FULL # Used by flock
    
    #http://tokemon.sb.statsbiblioteket.dk:9000/solr/net_4s_shard3_replica1/select?q=er+der
    export OUT_BASE="results_fmode=${FACET_MODE}_#facets=${FACETS}_facetLimit=${FACET_LIMIT}_hl=${HL}_threads=${THREADS}_run=${RUN}_solr=${SOLR_VERSION}_shards=${SHARDS}_optimized=${OPTIMIZED}_storage=${STORAGE}"
    export OUT_LOG="${DEST}/${OUT_BASE}.log"
    export OUT_LOG_FULL="${DEST}/${OUT_BASE}.log_full"

    CURRENT_BASE="$CALL_BASE"
    if [[ "$FACET_MODE" == "none" ]]; then
        CURRENT_BASE="$CURRENT_BASE&facet=false"
    else
        CURRENT_BASE="$CURRENT_BASE&facet=true&facet.limit=$FACET_LIMIT"
        if [[ "$FACETS" == "5" ]]; then
            CURRENT_BASE="$CURRENT_BASE&$FACETS5"
        elif [[ "$FACETS" == "6" ]]; then
            CURRENT_BASE="$CURRENT_BASE&$FACETS6"
        else
            >&2 echo "Unknown facets: $FACETS"
            exit 5;
        fi
    fi
    if [[ "$FACET_MODE" == "solr" ]]; then
        CURRENT_BASE="$CURRENT_BASE&facet.sparse=false"
    else
        CURRENT_BASE="$CURRENT_BASE&facet.sparse=true"
    fi
    if [[ "$FACET_MODE" == "skip" ]]; then
        CURRENT_BASE="$CURRENT_BASE&facet.sparse.skiprefinements=true"
    else
        CURRENT_BASE="$CURRENT_BASE&facet.sparse.skiprefinements=false"
    fi
    CURRENT_BASE="$CURRENT_BASE&hl=${HL}"
    TERMS="queries/queries_1k_${TERM_SOURCE}"

    echo "- $TEST_NUM/$TOTAL_TESTS $OUT_LOG"
    export CURRENT_BASE
    #echo "timeout ${TIMEOUT} cat \"$TERMS\" | head -n $MAX_QUERIES | tr '\n' '\0' | xargs -0 -P ${THREADS} -n 1 -I {} bash -c 'solr_request \"{}\"'"
    timeout ${TIMEOUT} cat "$TERMS" | head -n $MAX_QUERIES | tr '\n' '\0' | xargs -0 -P ${THREADS} -n 1 -I {} bash -c 'solr_request "{}"'
    rm $T $T_FULL
}

count_tests() {
    TOTAL_TESTS=0
    for THREADS in $THREADSS; do
        for FACET_MODE in $FACET_MODES; do
            if [[ ( "$FACET_MODE" == "skip" || "$FACET_MODE" == "sparse" ) && "." == .$(echo "$SOLR_VERSION" | grep "sparse") ]]; then
                continue
            fi
            for HL in $HLS; do
                # Break out to here
                for FACETS in $FACETSS; do
                    for FACET_LIMIT in $FACET_LIMITS; do
                        for RUN in $(seq 1 $RUNS); do
                            TOTAL_TESTS=$(( TOTAL_TESTS+1))
                            
                            TERM_SOURCE=$((TERM_SOURCE+1))
                            if [[ "$FACET_MODE" == "none" ]]; then
                                break 3;
                            fi
                        done
                    done
                done
            done
        done
    done
    export TOTAL_TESTS
}    

combine_setups() {
    count_tests
    TEST_NUM=0
    for THREADS in $THREADSS; do
        for FACET_MODE in $FACET_MODES; do
            if [[ ( "$FACET_MODE" == "skip" || "$FACET_MODE" == "sparse" ) && "." == .$(echo "$SOLR_VERSION" | grep "sparse") ]]; then
                continue
            fi
            for HL in $HLS; do
                # Break out to here
                for FACETS in $FACETSS; do
                    for FACET_LIMIT in $FACET_LIMITS; do
                        for RUN in $(seq 1 $RUNS); do
                            TEST_NUM=$(( TEST_NUM+1 ))
                            export TEST_NUM
                            run_tests
                            
                            TERM_SOURCE=$((TERM_SOURCE+1))
                            if [[ "$FACET_MODE" == "none" ]]; then
                                break 3;
                            fi
                        done
                    done
                done
            done
        done
    done
}

pack_full_logs() {
    gzip ${DEST}/*.log_full
}

check_parameters
dump_options > "${DEST}/measure.conf"
free -h > "${DEST}/free.log"
combine_setups
pack_full_logs

# This also clears the sparse pool, which is needed to avoid OOM when
# performing both Solr and psarse faceting
function reset_stats() {
    local T=`mktemp`
    wget "http://${SERVER}:${PORT}/${SOLRPATH}/collection1/${HANDLER}?q=hest&wt=json&rows=1&indent=true&rows=1&debugQuery=true" -O $T > /dev/null 2> /dev/null
    echo "============ `date +%Y%m%d-%H%M` $1" >> stats.log
    cat $T >> stats.log
    wget "http://${SERVER}:${PORT}/${SOLRPATH}/collection1/${HANDLER}?q=mxyzptlk&wt=json&indent=true&rows=1&facet.sparse.stats.reset=true" -O $T > /dev/null 2> /dev/null
    rm $T
}

TERM_SOURCE=$INITIAL_TERM_SOURCE
echo "Finished $(date +%Y%m%d-%H%M) with data in ${DEST}"
