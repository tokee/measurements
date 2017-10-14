#!/bin/bash

#
# Sends GZ-files to Solr
#

: ${COLLECTION:=net_4s}

: ${GZS:=999999}
: ${THREADS:=3}
: ${ROOT:="/mnt/bulk/np"}
: ${SOLR:="http://localhost:9000/solr/$COLLECTION"}

# Input: GZ

post() {
    GZ="$1"
    #echo "Posting $GZ to $SOLR"
    #echo "zcat \"$GZ\" | curl -H \"Content-Type: text/xml\" -X POST --data-binary @/dev/stdin \"$SOLR/update\""
   RESULT=$( zcat "$GZ" | curl -s -H "Content-Type: text/xml" -X POST --data-binary @/dev/stdin "$SOLR/update" )
    if [[ "." == ".$(echo \"$RESULT\" | grep '<int name=.status.>0</int>')" ]]; then
        >&2 echo "Error posting $GZ to $SOLR"
        >&2 echo "$RESULT"
    else
        echo "Posted $GZ in $( echo \"$RESULT\" | grep -o '<int name=.QTime.>[0-9]*</int>' | grep -o '[0-9]*' ) ms"
    fi
}
export -f post

echo "Sending $( echo \"$@\" | wc -w) updates to Solr at $SOLR"
# Ugly as it does not support spaces in paths
echo "$@" | tr ' ' '\n' | head -n $GZS | tr '\n' '\0' | xargs -0 -P $THREADS -n 1 -I {} bash -c "SOLR=\"$SOLR\" post \"{}\""

echo "Issuing commit to Solr at $SOLR"
RESULT=$( curl -s "$SOLR/update?commit=true" )
if [[ "." == ".$(echo \"$RESULT\" | grep '<int name=.status.>0</int>')" ]]; then
    >&2 echo "Error sending commit to $SOLR"
    >&2 echo "$RESULT"
else
    echo " - Finished commit in $( echo \"$RESULT\" | grep -o '<int name=.QTime.>[0-9]*</int>' | grep -o '[0-9]*' ) ms"
fi
