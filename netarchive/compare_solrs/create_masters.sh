#!/bin/bash

#
# Readies a Solr 4 installation and scps a Solr 4 shard from the Netarchive into it.
# This is used to create 2 products: A single shard of SINGLE_SHARD_SIZE GB and two
# shards half that size, by splitting it.
# The result is stored at the stated designation and the Solr installation is shut down.
#

pushd $(dirname "$0") > /dev/null
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

echo " - Copying source data from $SOURCE to $WORK"
# ###
#scp -r $SOURCE $WORK
#scp -rq $CONF $WORK

echo " - Setting up SolrCloud $VERSION"
pushd ../../solrcloud/ > /dev/null
REPLICAS=1 SHARDS=1 ./cloud_install.sh $VERSION
REPLICAS=1 SHARDS=1 ./cloud_start.sh $VERSION
./cloud_sync.sh 4.10.4-sparse $WORK/conf/ cremas_conf cremas
./cloud_stop.sh $VERSION

# TODO: Test with Solr 5+
pushd cloud/$VERSION/solr1/example/solr/cremas_shard1_replica1/data > /dev/null
rm -r index
ln -s $WORD/index index

REPLICAS=1 SHARDS=1 SOLR_MEM=$MASTER_SOLR_MEM ./cloud_start.sh $VERSION


# The code below is extremely specific to netarchive shards where the field hash
# containf base32 encoded values https://en.wikipedia.org/wiki/Base32 and each
# shard is ~900GB
echo " - Reducing shard to ~230GB"
DELQ="`echo \"*:* NOT (hash:sha1\:A* OR hash:sha1\:B* OR hash:sha1\:C* OR hash:sha1\:D* OR hash:sha1\:E* OR hash:sha1\:F* OR hash:sha1\:G* OR hash:sha1\:H*)\" | tr ' ' '+'`"

popd > /dev/null # solrcloud
