#!/bin/bash

#
# Helper for preparing Solrs with shards
#

pushd ${BASH_SOURCE%/*} > /dev/null 2> /dev/null
source compare.conf
source ../../solrcloud/general.conf

CC=../../solrcloud

optimize() {
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="$HOST:$SOLR_BASE_PORT"}

    # Took about 6 hours for 900GB -> 240GB on 7200 RPM
    echo " - Optimizing collection cremas (this can take hours)"
    echo "  - Before optimize: `du -BG $WORK/index`"
    local OPTIMIZE="http://$SOLR/solr/cremas/update/?optimize=true&waitFlush=true&maxSegments=1"
    curl "$OPTIMIZE"
    echo "  - After optimize: `du -BG $WORK/index`"
}

# Performs a test search and exits if the cloud is not available
# If success, the number of documents in the index is returned
# Input (optional) query
verify_cloud() {
    LSEQ="$1"
    : ${LSEQ:="*:*"}
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="$HOST:$SOLR_BASE_PORT"}
    local RETRIES=20
    local SLEEP=1
    
    local SEARCH_URL="http://$SOLR/solr/cremas/select?rows=0&q=$LSEQ"
    #echo "curl> $SEARCH_URL"
    local ATTEMPT=0
    while [ $ATTEMPT -lt $RETRIES ]; do
        local RES="`curl -m 5 -s \"$SEARCH_URL\"`"
        if [ ! "." == ".`echo \"$RES\" | grep \"Error 404 Not Found\"`" ]; then
            >&2 echo "   - Warning: Got 404 verifying cloud. Will sleep $SLEEP second then re-try $SEARCH_URL"
            local ATTEMPT=$(( ATTEMPT + 1 ))
            sleep $SLEEP
            continue
        fi
        local HITS=`echo "$RES" | grep -o "numFound=.[0-9]*" | grep -o "[0-9]*"`
        if [ ".$HITS" != "." ]; then
            if [ "$HITS" -ge "0" ]; then
                echo $HITS
                return
            fi
        fi
    done
    >&2 echo "Error: Unable to get hits for query '$LSEQ' from $SEARCH_URL"
    >&2 echo "$RES"
    echo -1
    exit 11
}

# Ensures that there is a cloud-setup
ensure_cloud() {
    local DEST_VERSION="$1"
    if [ ! -d "$CLOUD/$DEST_VERSION" ]; then
        echo "- Installing cloud for version $DEST_VERSION"
        # TODO: Figure out how to avoid the VAR=$VAR hack
        ( .  $CC/cloud_install.sh $DEST_VERSION )
        if [ ! -d "$CLOUD/$DEST_VERSION" ]; then
            >&2 echo "Error: Cloud expected at $CLOUD/$DEST_VERSION"
            exit 2
        fi
    else
        echo "- Using existing cloud at $CLOUD/$DEST_VERSION"
    fi
    # No need to start it as we only need the upgrade tool
}

# Ensures that there is a cloud-setup and that it is empty
fresh_cloud() {
    local VERSION="$1"

    if [ ! -d "$CLOUD/$VERSION" ]; then
        ensure_cloud $VERSION
        return
    fi
    # A cloud exists: Shut it down and remove it
    echo "- Shutting down and removing previous cloud at $CLOUD/$VERSION"
    ( . $CC/cloud_stop.sh $VERSION )
    rm -r "$CLOUD/$VERSION"
    ensure_cloud $VERSION
}

# Creates empty shards for the given Solr version and number of shards
ready_shards() {
    SOURCE_VERSION="$1"
    if [ -z "$SOURCE_VERSION" ]; then
        >&2 echo "Usage: ready_shard solr_version [shards]"
        exit 10
    fi
    local SHARDS=$2
    : ${SHARDS:=1}
    
    echo "- Readying SolrCloud $SOURCE_VERSION at $CLOUD/SOURCE_VERSION"
    fresh_cloud $SOURCE_VERSION
    echo "- Starting SolrCloud"
    ( . $CC/cloud_start.sh $SOURCE_VERSION )

    local SRC=$MASTER_DEST/$SOURCE_VERSION
    echo "- Creating empty $SHARDS shard collection"
    ( . $CC/cloud_sync.sh $SOURCE_VERSION $SRC/conf/ cremas_conf cremas )
    # Seems to need a moment to stabilize
    sleep 1
    verify_cloud
    echo "- Shutting down cloud"
    ( . $CC/cloud_stop.sh $SOURCE_VERSION )
}

