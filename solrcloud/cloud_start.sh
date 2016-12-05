#!/bin/bash

#
# Starts a specific SolrCloud
#

pushd $(dirname "$0") > /dev/null
source general.conf

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
if [ ! -d cloud/$VERSION ]; then
    echo "Attempting install of missing SolrCloud version $VERSION"
    ./cloud_install.sh $VERSION
    if [ ! -d cloud/$VERSION ]; then
        >&2 echo "Unable to install Solr version $VERSION"
        >&2 echo "Please run ./cloud_install.sh $VERSION manually and inspect the errors"
        exit 3
    else
        echo "Successfully installed SolrCloud $VERSION"
    fi
fi

pushd cloud/$VERSION > /dev/null

for Z in `seq 1 $ZOOS`; do
    if [ ! -d zoo$Z ]; then
        >&2 echo "Expected a ZooKeeper-instalation at `pwd`/zoo$S but found none."
        >&2 echo "Please run ./cloud_install.sh $VERSION"
        exit 4
    fi
    echo "calling> zoo$Z/bin/zkServer.sh start"
    zoo$Z/bin/zkServer.sh start
done

if [ ! "." == ".`echo \" 5.5.3 6.3.0 trunk trunk-7521 \" | grep \" $VERSION \"`" ]; then
    SOLR_HOME_SUB=server/solr/
else
    SOLR_HOME_SUB=example/solr/
fi
SOLR_PORT=$SOLR_BASE_PORT
for S in `seq 1 $SOLRS`; do
    if [ ! -d solr$S ]; then
        >&2 echo "Expected a Solr-instalation at `pwd`/solr$S but found none."
        >&2 echo "Please run ./cloud_install.sh $VERSION"
    fi
    echo "calling> solr$S/bin/solr -m $SOLR_MEM -cloud -s `pwd`/solr$S/$SOLR_HOME_SUB -p $SOLR_PORT -z $HOST:$ZOO_BASE_PORT -h $HOST"
    solr$S/bin/solr -m $SOLR_MEM -cloud -s `pwd`/solr$S/$SOLR_HOME_SUB -p $SOLR_PORT -z $HOST:$ZOO_BASE_PORT -h $HOST
    SOLR_PORT=$(( SOLR_PORT + 10 ))
done

popd > /dev/null # cloud/$VERSION

popd > /dev/null # pwd