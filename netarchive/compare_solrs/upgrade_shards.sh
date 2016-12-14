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

upgrade() {
    local SOURCE=$MASTER_DEST/$SOURCE_VERSION
    local DEST=$MASTER_DEST/$DEST_VERSION
    echo " - Upgrading $SOURCE_VERSION shards to $DEST_VERSION"
    for JOB in 1/1 2/1 2/2; do
        echo "   - Upgrading shard $JOB"
        if [ ! -d $SOURCE/$JOB ]; then
            >&2 echo "Error: The source '$SOURCE/$JOB' does not exist"
            continue
        fi
        if [ -d $DEST/$JOB ]; then
            echo "Not skipping although destination already exists, but this is due to development of the script"
            # ###
            #echo "Skipping upgrade: The destination '$DEST/$JOB' already exists"
            #continue
        fi
        # ###
        #mkdir -p $DEST/$JOB
        #echo "     - Copying files"
        #cp -r $SOURCE/$JOB/* $DEST/$JOB/
        if [ ! -d $DEST/conf ]; then
            cp -r $SOURCE/conf $DEST/
        fi
        SHARDS=`echo $JOB | cut -d/ -f1`
        # ###
        #ready_shards $DEST_VERSION

        echo "   - Linking $SHARDS shards from $SOURCE_VERSION to $DEST_VERSION"
        # ###
        ( . $CC/cloud_stop.sh $DEST_VERSION )
        for S in `seq 1 $SHARDS`; do
            pushd $CLOUD/$DEST_VERSION/solr1/server/solr/cremas_shard${S}_replica1/data > /dev/null
            rm -r index
            ln -s $SOURCE/${SHARDS}/${S}/index .
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
        
        exit
        
        echo "     - Calling Lucene IndexUpgrader"
        echo "exec> java -Xmx${UPGRADE_MEM} -cp $CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/ucene-backward-codecs-${DEST_VERSION}.jar:$CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/lucene-core-${DEST_VERSION}.jar org.apache.lucene.index.IndexUpgrader -verbose -delete-prior-commits $DEST/$JOB/index"
        # java -Xmx${UPGRADE_MEM} -cp $CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/ucene-backward-codecs-${DEST_VERSION}.jar:$CLOUD/$DEST_VERSION/solr1/server/solr-webapp/webapp/WEB-INF/lib/lucene-core-${DEST_VERSION}.jar org.apache.lucene.index.IndexUpgrader -verbose -delete-prior-commits $DEST/$JOB/index
    done
}

upgrade

echo "Done `date`"
