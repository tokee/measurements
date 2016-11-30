#!/bin/bash

# Visualizes the measurements across sources by concatenating all search results
#
# ./extract_result.sh must be run on each source before calling this script

pushd $(dirname "$0") > /dev/null

if [ -s performance.conf ]; then
    source performance.conf
fi
if [ ! "." == ".$CONF" ]; then # Override conf
    # Overriding defaults with custom config $CONF"
    source "$CONF"
fi

IFS=''
if [ "." == ".$1" ]; then
    echo "Usage: ./compare.sh \"source designation\"*"
    echo "Sample: ./compare.sh \"20161124-2224_full_Facets facets\" \"20161125-1528_full_NoFacets no_facets\""
    exit
fi
IFS="$OLDIFS"

mkdir -p t_cache
CDES=""
for S in $@; do
    SRC=$( echo "$S" | cut -d\  -f1 )
    DES=$( echo "$S" | cut -d\  -f2 )
    cat $SRC/search.[0-9].not0 > t_cache/$DES
    CDES="${CDES}_$DES"
done

pushd t_cache > /dev/null
OUT=../compare${CDES}.png MAXEXP=9 LOGY=false ../bucket.sh plotXYlogs *
echo "Created compare${CDES}.png"
popd > /dev/null

rm -r t_cache
