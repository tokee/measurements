#!/bin/bash

# Analyzes the results from a previous run_tests.sh

pushd $(dirname "$0") > /dev/null

if [ -s performance.conf ]; then
    source performance.conf
fi
if [ ! "." == ".$CONF" ]; then # Override conf
    # Overriding defaults with custom config $CONF"
    source "$CONF"
fi

if [ -z "$1" ]; then
    DATA=`ls -dr [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]* | head -n 1`
else
    DATA="$1"
fi

echo "Processing test results from $DATA"
pushd $DATA > /dev/null

# Get the configuration matching the test
if [ -s performance.conf ]; then
    source performance.conf
fi
if [ -s performance.include ]; then
    source performance.include
fi
_=${SKIPFIRST:=""}
_=${MAXTERMS:=4}
_=${YMAX:=6000}

# Individual visualizations
for TERMS in `seq 1 $MAXTERMS`; do
    echo "- Processing queries with $TERMS terms"
    if [ -s "search.${TERMS}.gz" ]; then
        zcat "search.${TERMS}.gz" | sed 's/.*QTime..\([0-9]*\).*numFound..\([0-9]*\).*/\2 \1/' | grep "[0-9]\+ [1-9][0-9]*" > "search.${TERMS}.not0"
    elif [ -s "search.${TERMS}.not0" ]; then
        echo "The raw Solr responses search.${TERMS} does not exist, but search.${TERMS}.not0 already exists"
    else
        echo "Error: Neither the raw Solr responses search.${TERMS}, nor search.${TERMS}.not0 exists. Unable to generate graph"
        continue
    fi
    # Simpler names
    cp "search.${TERMS}.not0" ${TERMS}-terms
    MAXEXP=9 LOGY=false ../bucket.sh plotXYlog "${TERMS}-terms"
done

# Merged visualization
OUT=1_to_${MAXTERMS}_terms.png MAXEXP=9 LOGY=false ../bucket.sh plotXYlogs *-terms
for TERMS in `seq 1 $MAXTERMS`; do
    if [ -s "${TERMS}-terms" ]; then
        rm "${TERMS}-terms"
    fi
done

popd > /dev/null
