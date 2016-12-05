#!/bin/bash

#
# Readies a Solr 4 installation and scps a Solr 4 shard from the Netarchive into it.
# This is used to create 2 products: A single shard of SINGLE_SHARD_SIZE GB and two
# shards half that size, by splitting it.
# The result is stored at the stated designation and the Solr installation is shut down.
#

pushd $(dirname "$0") > /dev/null
source ../../solrcloud/general.conf
source compare.conf

SOURCE="$1"
CONF="$2"

if [ "." == ".$SOURCE" -o "." == ".CONF" ]; then
    echo "Usage:  ./create_masters source conf"
    echo "Sample: ./create_masters user@example:/flash12/index/ user@example:/home/solr/collection1/conf"
    exit
fi

WORK=$MASTER_DEST/work
END=$MASTER_DEST/$VERSION

if [ -d "$END" ]; then
    echo "Skipping master creation as data are already present in $END"
    exit
fi

echo "Producing test-shards in $END"
mkdir -p $WORK

copy_shard() {
    echo " - Copying source data from $SOURCE to $WORK"
    # ###
    #scp -r $SOURCE $WORK
    #scp -rq $CONF $WORK
}
setup_cloud() {
    echo " - Setting up SolrCloud $VERSION"
    if [ ! -d $WORK/index ]; then
        >&2 echo "No shard index data available at $WORK/index"
        exit 4
    fi
    if [ ! -d $WORK/conf ]; then
        >&2 echo "No Solr config available at $WORK/conf"
        exit 5
    fi
    
    pushd ../../solrcloud/ > /dev/null
    SOLRS=1 ./cloud_install.sh $VERSION
    SOLRS=1 ./cloud_start.sh $VERSION
    SHARDS=1 REPLICAS=1 ./cloud_sync.sh 4.10.4-sparse $WORK/conf/ cremas_conf cremas
    ./cloud_stop.sh $VERSION
    
    # TODO: Test with Solr 5+
    pushd cloud/$VERSION/solr1/example/solr/cremas_shard1_replica1/data > /dev/null
    rm -r index
    ln -s $WORK/index index
    popd > /dev/null # data
    
    SOLRS=1 SOLR_MEM=$MASTER_SOLR_MEM ./cloud_start.sh $VERSION
    popd > /dev/null # solrcloud
}

reduce_shard() {
    # The code below is extremely specific to netarchive shards where the field hash
    # containf base32 encoded values https://en.wikipedia.org/wiki/Base32 and each
    # shard is ~900GB

    local DEL_PRES=$1
    local REM_HITS=$2

    _=${SOLR_BASE_PORT:=9000}
    _=${SOLR:="$HOST:$SOLR_BASE_PORT"}

    echo " - Reducing shard by removing documents with hash prefixes $DEL_PRES"
    local SEARCHQ=$( echo "$DEL_PRES" | sed -e 's/\(.\)/hash:sha1\\:\1*+OR+/g' -e 's/+OR+$//' )
    SEARCH_URL="http://$SOLR/solr/cremas/select?fl=hash&q=$SEARCHQ"

    echo "Performing test query"
    echo "curl> $SEARCH_URL"
    HITS=`curl -s "$SEARCH_URL" | grep -o "numFound=.[0-9]*" | grep -o "[0-9]*"`
    # TODO: Less hardcoding!
    if [ "$HITS" -lt $REM_HITS ]; then
        >&2 echo "Error: Expected at least $REM_HITS hits from test query, but got only $HITS. Perhaps the index is already reduced?"
        exit 7
    fi

    # curl http://46.231.77.98:7979/solr/update/?commit=true -H "Content-Type: text/xml" -d "<delete>(cartype:stationwagon)AND(color:blue)</delete>"
    echo "Performing delete of $HITS documents, to reduce index size to ~200GB"
    DEL_URL="http://$SOLR/solr/cremas/update/?commit=true&waitFlush=true&waitSearcher=true"
    # There seems to be a problem with : together with OR, so we iterate instead
    for BAS in `echo $DEL_PRES | sed 's/\(.\)/\1 /g'`; do
        echo $BAS
        DELXML="<delete><query>hash:sha1\:${BAS}*</query></delete>"
        echo "exec> curl $DEL_URL -H \"Content-Type: text/xml\" -d \"$DELXML\""
        curl $DEL_URL -H "Content-Type: text/xml" -d "$DELXML"
    done
}

optimize() {
    _=${SOLR_BASE_PORT:=9000}
    _=${SOLR:="$HOST:$SOLR_BASE_PORT"}

    echo " - Optimizing shard (this can take hours)"
    echo "  - Before optimize: `du -BG $WORK/index`"
    local OPTIMIZE="http://$SOLR/solr/cremas/update/?optimize=true&waitFlush=true&maxSegments=1"
    curl "$OPTIMIZE"
    echo "  - After optimize: `du -BG $WORK/index`"
}

create_master() {
    echo " - Creating master shard"
    reduce_shard IJKLMNOPQRSTUVWXYZ234567 150000000 # Leaves ABCDEFGH
    optimize
    echo " - Storing shard data"
    mkdir -p "$END/1/1/"
    cp -r "$WORK/index" "$END/1/1/"
}

# TODO: Control where SolrCloud is installed
# Input: EXISTING_SHARDS
split_shards() {
    local EXISTING="$1"
    local TARGET=$(( EXISTING * 2 ))
    echo " - Splitting $EXISTING shards into $TARGET"
    for E in `seq 1 $EXISTING`; do
        local SPLIT="http://$SOLR/solr/admin/collection=cremas&shard=cremas_shard${EXISTING}_replica1&action=SPLITSHARD"
        echo "curl> $SPLIT"
        curl "$SPLIT"
    done
    echo " - Storing $TARGET shards"
    for D in `seq 1 $TARGET`; do
        mkdir -p "$END/$TARGET/$D/"
        cp -r "../../solrcloud/cloud/$VERSION/solr1/example/solr/cremas_shardUNKNOWN1_replica1/data/index" "$END/$TARGET/$D/"
    done
}

echo "Start `date`"

#copy_shard
#setup_cloud
#create_master
#split_shards 1
#split_shards 2

echo "Done `date`"

