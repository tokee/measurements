#!/bin/bash

#
# Uses the Lucene upgrade tool to create upgraded versions of shards
#

pushd ${BASH_SOURCE%/*} > /dev/null
source compare.conf
source ../../solrcloud/general.conf
source cloud_control.sh

SOURCE_VERSION="$1"
DEST_VERSION="$2"
if [ "." == ".$SOURCE_VERSION" -o "." == ".$DEST_VERSION" ]; then
    >&2 echo "Usage: ./upgrade_shards.sh <source_version> <dest_version>"
    >&2 echo "Available versions: `echo \"$VERSIONS\" | sed 's/ / | /g'`"
    exit 1
fi

clean_up_segmentation() {
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="$HOST:$SOLR_BASE_PORT"}

    local DELETE_QUERY="id:1 OR id:2 OR id:3 OR id:4 OR id:5 OR id:6 OR id:7 OR id:8 OR id:9 OR id:10"
    echo "curl> \"$SOLR/solr/cremas/update?commit=true\" -H 'Contenttype: application/json' -d \"$DELETE_QUERY\""
    curl "$SOLR/solr/cremas/update?commit=true" -H 'Contenttype: application/json' -d "<delete><query>$DELETE_QUERY</query></delete>"
}
force_segmentation() {
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="$HOST:$SOLR_BASE_PORT"}
    
    echo "   - Forcing segmentation by adding $DOCS dummy documents"

    # Don't change the DOCS without changing clean_up_segmentation
    local DOCS=10
    local ADD="[{\"id\":\"1\"}"
    for D in `seq 2 $DOCS`; do
        local ADD="${ADD},{\"id\":\"$D\"}"
    done
    local ADD="${ADD}]"
    
    echo "curl> \"$SOLR/solr/cremas/update?commit=true\" -H 'Contenttype: application/json' -d \"$ADD\""
    curl "$SOLR/solr/cremas/update?commit=true" -H 'Contenttype: application/json' -d "$ADD"
}

upgrade() {
    local SOURCE=$MASTER_DEST/$SOURCE_VERSION
    local DEST=$MASTER_DEST/$DEST_VERSION
    echo " - Upgrading $SOURCE_VERSION shards to $DEST_VERSION"
    if [ ! -d $DEST/conf ]; then
        cp -r $SOURCE/conf $DEST/
    fi
    # ##
    for SHARDS in 2; do
        echo "   - Upgrading collection with $SHARDS shards"
        if [ ! -d $SOURCE/$SHARDS ]; then
            >&2 echo "Error: The source '$SOURCE/$SHARDS' does not exist"
            continue
        fi
        if [ -d $DEST/$SHARDS ]; then
            echo "Skipping upgrade: The destination '$DEST/$SHARDS' already exists"
            continue
        else
            mkdir -p $DEST
            echo "     - Copying files"
            cp -r $SOURCE/$SHARDS $DEST/
        fi
        # ###
        ready_shards $DEST_VERSION $SHARDS

        echo "   - Linking $SHARDS shards from $SOURCE_VERSION to $DEST_VERSION"

        ( . $CC/cloud_stop.sh $DEST_VERSION )
        for S in `seq 1 $SHARDS`; do
            pushd $CLOUD/$DEST_VERSION/solr1/server/solr/cremas_shard${S}_replica1/data > /dev/null
            rm -r index
            ln -s $DEST/${SHARDS}/${S}/index .
            popd > /dev/null
        done
        echo "   - Starting SolrCloud with linked index"
        ( . $CC/cloud_start.sh $DEST_VERSION )
        local HITS=`verify_cloud`
        if [ "$HITS" -le "0" ]; then
            >&2 echo "Error: The SolrCloud with the linked shards had a hit count of 0"
            exit 13
        else
            echo "   - Collection active with $HITS documents"
        fi
        force_segmentation
       local SEGHITS=`verify_cloud`
        if [ "$SEGHITS" -le "$HITS" ]; then
            >&2 echo "Error: After forced segmentatio of the collection, the hit count was lower than before: $SEGHITS/$HITS"
            exit 13
        else
            echo "   - Segmented collection active with $HITS documents"
        fi
 
        ( . $CC/cloud_stop.sh $DEST_VERSION )
        
        for S in `seq 1 $SHARDS`; do
            echo "     - Calling Lucene IndexUpgrader on shard $S/$SHARDS"
            echo "exec> java -Xmx${UPGRADE_MEM} -cp $CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/lucene-backward-codecs-${DEST_VERSION}.jar:$CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/lucene-core-${DEST_VERSION}.jar org.apache.lucene.index.IndexUpgrader -verbose -delete-prior-commits $DEST/${SHARD}/${S}/index"
            java -Xmx${UPGRADE_MEM} -cp $CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/lucene-backward-codecs-${DEST_VERSION}.jar:$CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/lucene-core-${DEST_VERSION}.jar org.apache.lucene.index.IndexUpgrader -verbose -delete-prior-commits $DEST/${SHARD}/${S}/index
            echo "   - Optimizing to single segment"
        done
        # This is clever enough to remove the dummy segment and thus does not require an optimize
        clean_up_segmentation
        echo "     - Finished upgrading $DEST"
    done
}

upgrade

echo "Done `date`"
