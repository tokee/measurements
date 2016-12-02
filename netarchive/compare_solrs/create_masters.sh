#!/bin/bash

#
# Readies a Solr 4 installation and scps a Solr 4 shard from the Netarchive into it.
# This is used to create 2 products: A single shard of SINGLE_SHARD_SIZE GB and two
# shards half that size, by splitting it.
# The result is stored at the stated designation and the Solr installation is shut down.
#

pushd $(dirname "$0") > /dev/null
source compare.conf

if [ -z $1 -o -z $2 ]; then
    echo "Usage:  ./create_masters source conf"
    echo "Sample: ./create_masters user@example:/flash12/index/ user@example:/home/solr/collection1/conf"
fi
SOURCE="$1"
CONF="$2"

WORK=$MASTER_DEST/work
END=$MASTER_DEST/$VERSION

if [ -d "$END" ]; then
    echo "Skipping master creation as data are already present in $END"
    exit
fi

echo "Producing test-shards in $END"
mkdir -p $WORK

echo " - Copying source data from $SOURCE to $WORK"
scp -r $SOURCE $WORK
scp -r $CONF $WORK

echo " - Setting up SolrCloud $VERSION"
