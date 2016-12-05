#!/bin/bash
set -e

#
# Uploads configurations and creates collections in SolrCloud
#

pushd $(dirname "$0") > /dev/null
source general.conf

function usage() {
    echo "Usage: ./cloud_sync.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`> <config_folder> <config_id> [collection]"
    exit $1
}
VERSION="$1"
CONFIG_FOLDER="$2"
CONFIG_NAME="$3"
COLLECTION="$4"

if [ "." == ".`echo \" $VERSIONS \" | grep \" $VERSION \"`" ]; then
    >&2 echo "The Solr version $VERSION is unsupported"
    usage 1
fi
if [ "." == ".$CONFIG_FOLDER" -o "." == ".$CONFIG_NAME" ]; then
    usage
fi
if [ ! -d $CONFIG_FOLDEr ]; then
    >&2 echo "The config folder '$CONFIG_FOLDER' does not exist"
    usage 2
fi
if [ ! -d cloud/$VERSION ]; then
    >&2 echo "No cloud present. Please install and start a cloud first with"
    >&2 echo "./cloud_install.sh $VERSION"
    >&2 echo "./cloud_start.sh $VERSION"
    exit 3
fi
pushd cloud/$VERSION > /dev/null

if [ "." == ".`echo \" 5.5.3 6.3.0 trunk trunk-7521 \" | grep \" $DEST \"`" ]; then
    _=${SOLR_SCRIPTS:="solr1/example/scripts/cloud-scripts"}
else
    _=${SOLR_SCRIPTS:="solr1/server/scripts/cloud-scripts"}
fi

# Resolve default
_=${HOST:=`hostname`}
_=${ZOO_BASE_PORT:=2181}
_=${ZOOKEEPER:="$HOST:$ZOO_BASE_PORT"}

_=${ZOO_BASE_PORT:=9000}
_=${SOLR:="$HOST:$SOLR_BASE_PORT"}
_=${SHARDS:=1}
_=${REPLICAS:=1}

_=${CONFIG_FOLDER:="config/solr/conf"}


# Upload the config if it is not already in the cloud
set +e
EXISTS="`$SOLR_SCRIPTS/zkcli.sh -zkhost $ZOOKEEPER -cmd list | grep \"/configs/$CONFIG_NAME/\"`" >> /dev/null 2>> /dev/null
set -e
if [ "." == ".$EXISTS" ]; then
    # Upload the config
    echo "Adding/updating Solr config $CONFIG_NAME from $CONFIG_FOLDER to ZooKeeper at $ZOOKEEPER"
    echo "> $SOLR_SCRIPTS/zkcli.sh -zkhost $ZOOKEEPER -cmd upconfig -confname $CONFIG_NAME -confdir \"$CONFIG_FOLDER\""
    $SOLR_SCRIPTS/zkcli.sh -zkhost $ZOOKEEPER -cmd upconfig -confname $CONFIG_NAME -confdir "$CONFIG_FOLDER"
else
    echo "Solr config $CONFIG_NAME already exists. Skipping upload"
fi

# Stop further processing if no collection is specified
if [ -z $COLLECTION ]; then
    echo "Skipping collection creation as no collection is specified"
    exit
fi

# Update existing or create new collection
set +e
EXISTS=`curl -m 30 -s "http://$SOLR/solr/admin/collections?action=LIST" | grep -o "<str>${COLLECTION}</str>"`
set -e
if [ "." == ".$EXISTS" ]; then

    # Create new collection
    echo "Collection $COLLECTION does not exist. Creating new $SHARDS shard collection with $REPLICAS replicas and config $CONFIG_NAME"
    URL="http://$SOLR/solr/admin/collections?action=CREATE&name=${COLLECTION}&numShards=${SHARDS}&maxShardsPerNode=${SHARDS}&replicationFactor=${REPLICAS}&collection.configName=${CONFIG_NAME}"
    echo "request> $URL"
    RESPONSE="`curl -m 60 -s \"$URL\"`"
    if [ ! -z "`echo "$RESPONSE" | grep "<int name=\"status\">0</int>"`" ]; then
        >&2 echo "Failed to create collection ${COLLECTION} with config ${CONFIG_NAME}:"
        >&2 echo "$RESPONSE"
        exit 1
    fi
    
    set +e
    EXISTS=`curl -m 30 -s "http://$SOLR/solr/admin/collections?action=LIST" | grep -o "<str>${COLLECTION}</str>"`
    set -e
    if [ "." == ".$EXISTS" ]; then
        >&2 echo "Although the API call for creating the collection $COLLECTION responded with success, the collection is not available in the cloud. This is likely due to problems with solrconfig.xml or schema.xml in config set ${CONFIG_NAME}."
        exit 2
    fi

    echo "Collection with config $CONFIG_NAME available at http://$SOLR/solr/"
else

    # Update existing collection
    echo "Collection $COLLECTION already exist. Assigning config $CONFIG_NAME"
    $SOLR_SCRIPTS/zkcli.sh -zkhost $ZOOKEEPER -cmd linkconfig -collection $COLLECTION -confname $CONFIG_NAME

    echo "Reloading collection $COLLECTION"
    RESPONSE=`curl -m 120 -s "http://$SOLR/solr/admin/collections?action=RELOAD&name=$COLLECTION"`
    if [ -z "`echo \"$RESPONSE\" | grep \"<int name=.status.>0</int>\"`" ]; then
        >&2 echo "Failed to reload collection ${COLLECTION}:"
        >&2 echo "$RESPONSE"
        exit 1
    fi
fi

popd > /dev/null
