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

force_segmentation() {
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="$HOST:$SOLR_BASE_PORT"}
    
    echo "   - Forcing segmentation by adding $DOCS dummy documents"
    if [ `verify_cloud` -le 0 ]; then
        >&2 echo "Unable to segment index as it contains no documents"
        exit 15
    fi
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
clean_up_segmentation() {
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="$HOST:$SOLR_BASE_PORT"}

    if [ `verify_cloud` -le 0 ]; then
        >&2 echo "Unable to clean up segmented index as it contains no documents"
        exit 16
    fi
    local DELETE_QUERY="id:1 OR id:2 OR id:3 OR id:4 OR id:5 OR id:6 OR id:7 OR id:8 OR id:9 OR id:10"
    echo "curl> \"$SOLR/solr/cremas/update?commit=true\" -H 'Contenttype: application/json' -d \"$DELETE_QUERY\""
    curl "$SOLR/solr/cremas/update?commit=true&waitSearcher=true" -H 'Contenttype: application/json' -d "<delete><query>$DELETE_QUERY</query></delete>"
    if [ `verify_cloud` -le 0 ]; then
        >&2 echo "Unable to get document count after segment clean up"
        exit 26
    fi
}

upgrade() {
    local SOURCE=$MASTER_DEST/$SOURCE_VERSION
    local DEST=$MASTER_DEST/$DEST_VERSION
    echo " - Upgrading $SOURCE_VERSION shards to $DEST_VERSION"
    if [ ! -d $DEST/conf ]; then
        mkdir -p $DEST
        cp -r $SOURCE/conf $DEST
        if [ ! -d "$DEST/conf" ]; then
            >&2 echo "Error: Could not copy conf from $SOURCE/conf to $DEST/conf"
            exit 14
        fi
        if [ ! "." == ".`echo \" 5.5.3 6.3.0 trunk trunk-7521 \" | grep \" $DEST_VERSION \"`" ]; then
            echo "     - Removing 5.5.3+ deprecated elements from setup"
            sed -i -e 's/enablePositionIncrements=.true.//' $DEST/conf/schema.xml
        fi
        if [ ! "." == ".`echo \" 6.3.0 trunk trunk-7521 \" | grep \" $DEST_VERSION \"`" ]; then
            echo "     - Removing 6.3.0+ deprecated elements from setup"
            sed -i -e 's/<requestHandler name=\"\/admin\/\"//' -e 's/class=.solr.admin.AdminHandlers. .>//' $DEST/conf/solrconfig.xml
        fi

        local MATCH_VERSION=$DEST_VERSION
        if [ ! "." == ".`echo \" trunk trunk-7521 \" | grep \" $DEST_VERSION \"`" ]; then
            local MATCH_VERSION=7.0.0
        fi
        sed -i -e "s/<luceneMatchVersion>[0-9.]*<\/luceneMatchVersion>/<luceneMatchVersion>$MATCH_VERSION<\/luceneMatchVersion>/" $DEST/conf/solrconfig.xml
    fi

    for SHARDS in `seq 1 2`; do
        echo "   - Upgrading collection with $SHARDS shards"
        if [ ! -d $SOURCE/$SHARDS ]; then
            >&2 echo "Error: The source '$SOURCE/$SHARDS' does not exist"
            continue
        fi
        if [ -d $DEST/$SHARDS ]; then
            echo "Skipping upgrade: The destination '$DEST/$SHARDS' already exists"
            continue
        else
            mkdir -p $DEST/$SHARDS
            echo "     - Copying shards from $SOURCE/$SHARDS/*"
            cp -rL $SOURCE/$SHARDS/* $DEST/$SHARDS
        fi

#        echo "   - Creating empty structures for $SHARDS shards for $DEST_VERSION"
        fresh_cloud $DEST_VERSION
        ( . $CC/cloud_start.sh $DEST_VERSION )
        local SRC=$MASTER_DEST/$SOURCE_VERSION
        echo "   - Uploading config from $DEST/conf"
        ( . $CC/cloud_sync.sh $DEST_VERSION $DEST/conf/ cremas_conf )
        ( . $CC/cloud_stop.sh $DEST_VERSION )
        
        ### ready_shards $DEST_VERSION $SHARDS

        #echo "   - Linking $SHARDS shards from $SOURCE_VERSION to $DEST_VERSION"
        echo "   - Copying $SHARDS shards to $DEST_VERSION"

        pushd $CLOUD/$DEST_VERSION/solr1/server/solr > /dev/null
        #rm -r cremas_*/data/index
        rm -rf cremas_*/
        for S in `seq 1 $SHARDS`; do
            local LSRC=$DEST/${SHARDS}/cremas_shard${S}_replica1
            if [ ! -d $LSRC/data/index ]; then
                >&2 echo "Error: Want to link, but the end-point does not exist: $LSRC/data/index"
                exit 19
            fi
            
            #ln -s $LSRC/data/index cremas_shard${S}_replica1/data/index
            #cp -r $LSRC cremas_shard${S}_replica1
            ln -s $LSRC .
        done
        popd > /dev/null # solr

        #echo "*********************** Before start: `pwd`"
        #ls -l $CLOUD/$DEST_VERSION/solr1/server/solr/cremas*/data/index/
        #cat $CLOUD/$DEST_VERSION/solr1/server/solr/cremas*/core.properties

        echo "   - Starting SolrCloud"
        ( . $CC/cloud_start.sh $DEST_VERSION )

        #echo "*********************** After start: `pwd`"
        #ls -l $CLOUD/$DEST_VERSION/solr1/server/solr/cremas*/data/index/
        #cat $CLOUD/$DEST_VERSION/solr1/server/solr/cremas*/core.properties

        #echo "   - Creating collection with existing folders"
        #( . $CC/cloud_sync.sh $DEST_VERSION $DEST/conf/ cremas_conf cremas )

        #echo "*********************** After collection creation: `pwd`"
        #ls -l $CLOUD/$DEST_VERSION/solr1/server/solr/cremas*/data/index/
        #cat $CLOUD/$DEST_VERSION/solr1/server/solr/cremas*/core.properties
        
        local HITS=`verify_cloud`
        if [ "$HITS" -le "0" ]; then
            >&2 echo "Error: The SolrCloud with the linked shards had a hit count of 0"
            exit 13
        fi
        echo "   - Collection active with $HITS documents"
        force_segmentation
        local SEGHITS=`verify_cloud`
        if [ "$SEGHITS" -le "$HITS" ]; then
            >&2 echo "Error: After forced segmentatio of the collection, the hit count was not higher than before: $SEGHITS/$HITS"
            exit 21
        else
            echo "   - Segmented collection active with $SEGHITS documents, up from $HITS documents"
        fi
 
        ( . $CC/cloud_stop.sh $DEST_VERSION )
        
        for S in `seq 1 $SHARDS`; do
                local SN=$DEST/${SHARDS}/cremas_shard${S}_replica1
            if [ ! -d $SN ]; then
                >&2 echo "Error: Expected index data not found: $SN"
                exit 17
            fi
            
            echo "     - Calling Lucene IndexUpgrader on shard $SN"
            local LIB_BACK=`ls $CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/lucene-backward-codecs-*.jar`
            local LIB_CORE=`ls $CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/lucene-core-*.jar`
            echo "exec> java -Xmx${UPGRADE_MEM} -cp ${LIB_BACK}:${LIB_CORE} org.apache.lucene.index.IndexUpgrader -verbose -delete-prior-commits $SN/data/index"
            java -Xmx${UPGRADE_MEM} -cp ${LIB_BACK}:${LIB_CORE} org.apache.lucene.index.IndexUpgrader -verbose -delete-prior-commits $SN/data/index
        done
        # This is clever enough to remove the dummy segment and thus does not require an optimize
        echo "     - Cleaning up temporary segmentation"
        ( . $CC/cloud_start.sh $DEST_VERSION )
        clean_up_segmentation
        ( . $CC/cloud_stop.sh $DEST_VERSION )
        rm $DEST/*/*/data/index/write.lock
        echo "     - Finished upgrading $DEST"
    done
}

upgrade

echo "Done `date`"
