#!/bin/bash

#
# Stops a specific SolrCloud
#
# TODO: Figure out which cloud is running and stop it, so that version need not be specified
#

pushd ${BASH_SOURCE%/*} > /dev/null
source general.conf

: ${CLOUD:=`pwd`/cloud}

function usage() {
    echo "Usage: ./cloud_start.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`>"
    echo ""
    echo "Installed SolrClouds: `ls cloud | tr '\n' ' '`"
    exit $1
}

if [ -z $1 ]; then
    echo "No Solr version specified."$'\n'
    usage
fi
VERSION="$1"
if [ "." == ".`echo \" $VERSIONS \" | grep \" $VERSION \"`" ]; then
    >&2 echo "The Solr version $VERSION is unsupported"
    usage 1
fi
if [ ! -d ${CLOUD}/$VERSION ]; then
    >&2 echo "The Solr version $VERSION is not installed."
    >&2 echo "Please run ./install_cloud.sh $VERSION"
    exit 3
fi

pushd ${CLOUD}/$VERSION > /dev/null


SOLR_PORT=$SOLR_BASE_PORT
for S in `seq 1 $SOLRS`; do
    if [ ! -d solr$S ]; then
        >&2 echo "Expected a Solr-instalation at `pwd`/solr$S but found none."
        >&2 echo "Please run ./cloud_install.sh $VERSION"
        return
    fi
    solr$S/bin/solr stop -p $SOLR_PORT
    SOLR_PORT=$(( SOLR_PORT + 10 ))
done
   
# Be sure to shut down the ZooKeepers last
for Z in `seq 1 $ZOOS`; do
    if [ ! -d zoo$Z ]; then
        >&2 echo "Expected a ZooKeeper-instalation at `pwd`/zoo$S but found none."
        >&2 echo "Please run ./cloud_install.sh $VERSION"
        return
    fi
    zoo$Z/bin/zkServer.sh stop
done

popd > /dev/null # ${CLOUD}/$VERSION

popd > /dev/null # pwd
