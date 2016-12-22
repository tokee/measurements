#!/bin/bash

#
# Readies a Solr 4 installation and scps a Solr 4 shard from the Netarchive into it.
# This is used to create 2 products: A single shard of SINGLE_SHARD_SIZE GB and two
# shards half that size, by splitting it.
# The result is stored at the stated designation and the Solr installation is shut down.
#

pushd ${BASH_SOURCE%/*} > /dev/null
source compare.conf
source ../../solrcloud/general.conf
source cloud_control.sh

SOURCE="$1"
CONF="$2"
: ${MULTI_SHARDS:=2}
: ${SOLR_BASE_PORT:=9000}
: ${SOLR:="$HOST:$SOLR_BASE_PORT"}

if [ "." == ".$SOURCE" -o "." == ".CONF" ]; then
    echo "Usage:  ./create_masters source conf"
    echo "Sample: ./create_masters user@example:/flash12/index/ user@example:/home/solr/collection1/conf"
    exit
fi

WORK=$MASTER_DEST/work
END=$MASTER_DEST/$VERSION

function check_existing() {
    if [ -d "$END" ]; then
        echo "Skipping master creation as data are already present in $END"
        exit
    fi
}

copy_shard() {
    if [ ! -d "$WORK/index" ]; then
        echo " - Copying index data from $SOURCE to $WORK"
        scp -r $SOURCE $WORK
    fi
    if [ ! -d "$WORK/conf" ]; then
        echo " - Copying conf data from $SOURCE to $WORK"
        scp -rq $CONF $WORK
    fi
}

setup_cloud() {
    echo " - Setting up SolrCloud $VERSION"
    if [ ! -d $WORK/index ]; then
        >&2 echo "Error: No shard index data available at $WORK/index"
        exit 4
    fi
    if [ ! -d $WORK/conf ]; then
        >&2 echo "Error: No Solr config available at $WORK/conf"
        exit 5
    fi
    if [ -d $CLOUD/$VERSION ]; then
        >&2 echo "Error: Solr work folder $CLOUD/$VERSION already exists"
        exit 7
    fi

    pushd ../../solrcloud/ > /dev/null
    SOLRS=1
    ( . ./cloud_install.sh $VERSION )
    
    # Start up Solr and create an empty collection
    ( . ./cloud_start.sh $VERSION )
    SHARDS=1
    REPLICAS=1
    ( . ./cloud_sync.sh $VERSION $WORK/conf/ cremas_conf cremas )
    ( . ./cloud_stop.sh $VERSION )

    # Link the shard data into Solr
    # TODO: Test with Solr 5+
    pushd $CLOUD/$VERSION/solr1/example/solr/cremas_shard1_replica1/data > /dev/null
    rm -r index
    ln -s $WORK/index .
    popd > /dev/null # data
    
    SOLRS=1
    SOLR_MEM=$MASTER_SOLR_MEM
    ( . ./cloud_start.sh $VERSION )
    popd > /dev/null # solrcloud
}

reduce_shard() {
    # The code below is extremely specific to netarchive shards where the field hash
    # containf base32 encoded values https://en.wikipedia.org/wiki/Base32 and each
    # shard is ~900GB

    local DEL_PRES=$1
    local REM_HITS=$2

    echo " - Reducing shard by removing documents with hash prefixes $DEL_PRES"
    local SEARCHQ=$( echo "$DEL_PRES" | sed -e 's/\(.\)/hash:sha1\\:\1*+OR+/g' -e 's/+OR+$//' )
    SEARCH_URL="http://$SOLR/solr/cremas/select?fl=hash&q=$SEARCHQ"

    echo "Performing test query"
    echo "curl> $SEARCH_URL"
    HITS=`verify_cloud`
    # TODO: Less hardcoding!
    if [ "$HITS" -lt $REM_HITS ]; then
        >&2 echo "Error: Expected at least $REM_HITS hits from test query, but got only $HITS. Perhaps the index is already reduced?"
        return
    fi

    # curl http://46.231.77.98:7979/solr/update/?commit=true -H "Content-Type: text/xml" -d "<delete>(cartype:stationwagon)AND(color:blue)</delete>"
    echo "Performing delete of $HITS documents, to reduce index size to ~200GB"
    DEL_URL="http://$SOLR/solr/cremas/update/?commit=true&waitFlush=true&waitSearcher=true"
    # There seems to be a problem with : together with OR, so we iterate instead
    for BAS in `echo $DEL_PRES | sed 's/\(.\)/\1 /g'`; do
        echo $BAS
        # ###
        DELXML="<delete><query>hash:sha1\:${BAS}*</query></delete>"
        echo "exec> curl $DEL_URL -H \"Content-Type: text/xml\" -d \"$DELXML\""
        curl $DEL_URL -H "Content-Type: text/xml" -d "$DELXML"
    done
    local AHITS=`verify_cloud`
    echo "Finished reducing collection. Hits down to $AHITS from $HITS"
}

store_shards() {
    local TARGET=$1
    : ${TARGET:=2}
    
    if [ ! -d $END/conf ]; then
        cp -r "$WORK/conf" "$END/"
    fi
    if [ -d "$END/$TARGET/" ]; then
        echo "Warning: Storing $TARGET shards might fail as destination $END/$TARGET/ already exists"
    fi
    
    for D in `seq 1 $TARGET`; do
        echo " - Storing shard $D/$TARGET"
        local SI=$(( D - 1))
        if [ "$TARGET" -eq 1 ]; then
            local S="$CLOUD/$VERSION/solr1/example/solr/cremas_shard$1_replica1"
        else
                local S="$CLOUD/$VERSION/solr1/example/solr/cremas_shard1_${SI}_replica1"
        fi
        
        if [ ! -d "$S" ]; then
            >&2 echo "Error: Source for generated shard $D not found: $S"
            exit 9
        fi
        mkdir -p "$END/$TARGET/"
        cp -r "$S" "$END/$TARGET/"
        rm $END/$TARGET/*/data/index/write.lock
    done

}

create_master() {
    echo " - Reducing master shard to ~240GB"
    reduce_shard IJKLMNOPQRSTUVWXYZ234567 $RAW_MIN_DOCS # Leaves ABCDEFGH
    echo " - Optimizing master shard"
    optimize

    store_shards 1
}


# Input: (optional) target shards
split_master() {
    local TARGET=$1
    : ${TARGET:=2}
    if [ $TARGET -lt 2 ]; then
        >&2 echo "Splitting master shards into $TARGET shards does not make sense"
        exit 8
    fi
    
    echo " - Splitting master shard into $TARGET"
    verify_cloud
    local SPLIT="http://$SOLR/solr/admin/collections?action=SPLITSHARD&collection=cremas&shard=shard1"
    echo "curl> $SPLIT"
    # TODO: Problem: The splitshard command times out but continue in the background
    # Busy-waiting for the splits is one way of handling this
    curl "$SPLIT"
    store_shards $TARGET
}

echo "Start `date`"

check_existing
echo "Producing test-shards in $END"
mkdir -p $WORK

copy_shard
setup_cloud
create_master
split_master $MULTI_SHARDS

echo "Done `date`"
