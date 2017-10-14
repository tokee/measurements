#!/bin/bash

# Extracts the top-X terms from the fulltext field in a Netarchive Search shard
# and produces artificial queries.

# Only seems to work with stock Solr 4?

pushd $(dirname "$0") > /dev/null

if [ -s performance.conf ]; then
    source performance.conf
fi
if [ -s "$1" ]; then # Override conf
    source "$1"
fi
: ${SOLR:="http://localhost:9010/solr/net_2s"}
: ${QUERYFOLDER:=queries}
: ${TOPFIELD:=text}
: ${TOPX:=100000}
: ${TOPCUT:=10}
: ${MAXTERMS:=4}
: ${QUERYCOUNT:=5000000}

: ${THREADS=8}

export SOLR

get_hits() {
    #>&2 echo "curl -s --get --data-urlencode \"q=$1\" \"$SOLR/select?wt=json&indent=true&rows=0&facet=false&hl=false\" | jq '.response.numFound'"
    curl -s --get --data-urlencode "q=$1" "$SOLR/select?wt=json&indent=true&rows=0&facet=false&hl=false" | jq '.response.numFound'
}
export -f get_hits

mkdir -p $QUERYFOLDER
pushd $QUERYFOLDER > /dev/null
if [ -s top.raw ]; then
    echo "Skipping top.raw as it already exists"
else
    echo "Creating top.raw"
    URL="$SOLR/terms?terms.sort=count&terms.limit=$TOPX&terms.fl=$TOPFIELD"
    echo "Requesting $URL"
    curl "$URL" > top.raw
fi

if [[ -s top.num_word ]]; then
    echo "Skipping top.num_word as it already exists"
else
    echo "Creating top.num_word"
    cat top.raw | grep -o "QTime.*" |  grep -o "<int name=\"[^\"]*\">[0-9]*" | sed 's/<int name=\"\([^\"]*\)">\([0-9]*\).*/\2 \1/' | grep -v "[:&\"]" | tail -n +$TOPCUT > top.num_word
fi
cat top.num_word | cut -d\  -f2 > top.word


for TERMS in `seq 1 $MAXTERMS`; do
    REGEXP="[^ ]\+"
    for T in `seq 2 $TERMS`; do
        REGEXP="$REGEXP [^ ]\+"
    done

    if [[ -s queries.${TERMS} ]]; then
        echo "Skipping queries.${TERMS} as it already exists"
    else
        echo "Creating queries.${TERMS}"
        cat top.word | sort -R --random-source=/dev/zero | tr '\n' ' ' | grep -o "$REGEXP" | head -n $QUERYCOUNT > queries.${TERMS}
        if [[ "$TERMS" -gt "1" ]]; then
            cat top.word top.word top.word | shuf --random-source=/dev/zero | tr '\n' ' ' | grep -o "$REGEXP" | head -n $QUERYCOUNT > queries.${TERMS}.b
        fi        
    fi
done

if [[ -s queries.mix ]]; then
    echo "Skipping queries.mix as it already exists"
else
    echo "Creating queries.mix"
    cat queries.[1-9]* | LC_LOCALE=C sort | LC_LOCALE=C uniq | shuf --random-source=/dev/zero > queries.mix
fi

verify() {
    local OLDQ="N/A"
    local QUERY=$( echo "$1" | sed -e 's/^/+/' -e 's/ \+\([^ ]\)/ +\1/g' -e 's/^+\([^ ]*\)$/\1/' )
    local HITS=$( get_hits "$QUERY" )
    while [[ "$HITS" -eq "0" && "$OLDQ" != "$QUERY" ]]; do
        local OLDQ="$QUERY"
        local QUERY=$( echo "$QUERY" | sed 's/+//' )
        local HITS=$( get_hits "$QUERY" )
    done
    if [[ "$HITS" -ne "0" ]]; then
        flock -w 2 200 echo "$QUERY"
    else
        >&2 echo "Sanity check error: Unable to get hits for $QUERY"
    fi
}
export -f verify

# Make sure all queries gives hits > 0
if [[ -s queries.clean ]]; then
    echo "Skipping queries.clean as it already exists"
else
    T=$(mktemp)
    201>$T # Used by flock

    TOTAL=$( wc -l queries.mix )
    echo "Verifying $TOTAL queries into queries.clean. This might take a while"
    cat "queries.mix" | tr '\n' '\0' | xargs -0 -P ${THREADS} -n 1 -I {} bash -c 'verify "{}"' > queries.clean

    rm $T
fi

echo "Creating queries_1k_*"
rm -f queries_1k_*
split -l 1000 -a 3 -d queries.clean queries_1k_
rename 's/_00?/_/' queries_1k_0*

popd > /dev/null
