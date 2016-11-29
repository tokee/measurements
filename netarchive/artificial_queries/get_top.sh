#!/bin/bash

# Extracts the top-X terms from the fulltext field in a Netarchive Search shard
# and produces artificial queries.

pushd $(dirname "$0") > /dev/null

if [ -s performance.conf ]; then
    source performance.conf
fi
if [ -s "$1" ]; then # Override conf
    source "$1"
fi
_=${SOLR:="http://example.com:8983/solr/collection1"}
_=${QUERYFOLDER:=queries}
_=${TOPFIELD:=text}
_=${TOPX:=26000}
_=${TOPCUT:=10}
_=${MAXTERMS:=4}
_=${QUERYCOUNT:=5000}

mkdir -p $QUERYFOLDER
pushd $QUERYFOLDER > /dev/null
if [ -s top.raw ]; then
    echo "The file top-raw already exists. Skipping"
else
    URL="$SOLR//terms?terms.sort=count&terms.limit=$TOPX&terms.fl=$TOPFIELD"
    echo "Requesting $URL"
    curl "$URL" > top.raw
fi

cat top.raw | grep -o "QTime.*" |  grep -o "<int name=\"[^\"]*\">[0-9]*" | sed 's/<int name=\"\([^\"]*\)">\([0-9]*\).*/\2 \1/' | grep -v "[:&\"]" | tail -n +$TOPCUT > top.num_word
cat top.num_word | cut -d\  -f2 > top.word


for TERMS in `seq 1 $MAXTERMS`; do
    REGEXP="[^ ]\+"
    for T in `seq 2 $TERMS`; do
        REGEXP="$REGEXP [^ ]\+"
    done
    
    cat top.word | sort -R --random-source=/dev/zero | tr '\n' ' ' | grep -o "$REGEXP" | head -n $QUERYCOUNT > queries.${TERMS}
done

popd > /dev/null
