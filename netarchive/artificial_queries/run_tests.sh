#!/bin/bash

# Runs performance tests against the SolrCloud

# TODO: Phrase searches, facet on/off, grouping, heavy queries (top-X terms)

pushd $(dirname "$0") > /dev/null

if [ -s performance.conf ]; then
    source performance.conf
fi
if [ ! "." == ".$CONF" ]; then # Override conf
    echo "Overriding defaults with custom config $CONF"
    source "$CONF"
fi

_=${SOLR:="http://example.com:8983/solr/collection1"}
_=${QUERYFOLDER:=queries}
_=${MAXTERMS:=4}
_=${TESTQUERIES:=2000}

_=${QEXTRA:=""}
_=${FACET:="true"}
_=${SPARSE:="true"}
_=${FACETFIELDS:="public_suffix content_type_norm crawl_year domain links_domains"}
_=${FACETLIMIT:=10}
_=${FL:="id,source_file_s,url_norm,host,domain,content_type_served,content_length,crawl_date,content_language"}

if [ ! -d $QUERYFOLDER ]; then
    >&2 echo "Error: The query folder \"$QUERYFOLDER\" does not exist."
    >&2 echo "It must be created with ./get_top.sh before executing ./run_tests.sh."
    exit 1
fi
if [ ! "." == ".$1" ]; then
    DEST="$1"
else
    DEST=`date +%Y%m%d-%H%M`
fi
echo "Storing test results in $DEST"
mkdir -p "$DEST"

QBASE="wt=json"
BASEURL="${SOLR}/select?${QBASE}&${QEXTRA}`echo \" $FACETFIELDS\" | sed 's/ \+/\&facet.field=/g'`&facet=${FACET}&fl=${FL}&facet.limit=${FACETLIMIT}&facet.sparse=${SPARSE}"

for TERMS in `seq 1 $MAXTERMS`; do
    QUERIES=$QUERYFOLDER/queries.${TERMS}
    if [ ! -s $QUERIES ]; then
        >2& echo "Unable to locate $QUERIES from `pwd`"
        continue
    fi

    echo "Issuing $TESTQUERIES queries with $TERMS terms"
    COUNT=1
    while IFS= read -r QUERY; do
        URL="$BASEURL&q=`echo -n "$QUERY" | tr ' ' '+'`"
        echo "- $COUNT/$TESTQUERIES: $QUERY"
        curl -s "$URL" >> "$DEST/search.${TERMS}"
        COUNT=$(( COUNT+1 ))
        if [ $COUNT -gt $TESTQUERIES ]; then
            break
        fi
    done < $QUERIES
done
if [ -s performance.conf ]; then
    cp performance.conf $DEST
fi
if [ ! "." == ".$CONF" ]; then
    cp "$CONF" $DEST
    cp run_tests.sh $DEST
    BAS=`basename "$CONF"`
    echo "source \"$BAS\"" > $DEST/performance.include
fi

popd > /dev/null
