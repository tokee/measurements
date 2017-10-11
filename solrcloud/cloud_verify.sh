#!/bin/bash

#
# Verifies that Solr is up and running with a specified collection
#
# Outputs either total hitCount or "na"

pushd ${BASH_SOURCE%/*} > /dev/null
source general.conf
: ${CLOUD:=`pwd`/cloud}

function usage() {
    echo "Usage: ./cloud_verify.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`> <collection>"
    echo ""
    echo "Installed SolrClouds: `ls ${CLOUD} | tr '\n' ' '`"
    exit $1
}

if [[ -z "$1" && -z "$VERSION" ]]; then
    echo "No Solr version specified."$'\n'
    usage 2
elif [[ ! -z "$1" ]]; then
    VERSION="$1"
fi
if [[ -z "$2" && -z "$COLLECTION" ]]; then
    echo "No Solr collection specified."$'\n'
    usage 3
elif [[ ! -z "$2" ]]; then
    COLLECTION="$2"
fi

: ${SOLR:="${HOST}:${SOLR_BASE_PORT}/solr"}


URL="${SOLR}/${COLLECTION}/select?q=*:*&rows=0&facet=false&hl=false&wt=json"
#echo "curl> $URL"
RESULT=$(curl -s "$URL")
if [[ "." == "$RESULT" ]]; then
    echo "na"
else
#    echo "$RESULT"
    HITS=$( echo "$RESULT" | jq '.response.numFound' )
#    echo $HITS
    # Hack to check for integer
    if [[ "$HITS" -ge "0" ]]; then
        echo $HITS
    else
        echo "na"
    fi
fi
