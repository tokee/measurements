#!/bin/bash

#
# Installs a specific SolrCloud
#

pushd $(dirname "$0") > /dev/null
source general.conf

function usage() {
    echo "Usage: ./cloud_install.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`>"
    exit $1
}

if [ -z $1 ]; then
    echo "No Solr version specified."$'\n'
    usage
fi

# Input: Package
function check_package() {
    if [ ! -s cache/$1 ]; then
        echo "Activating get_solr.sh as package $1 is not available"
        ./get_solr.sh
        if [ ! -s cache/$1 ]; then
            >&2 "Error: Package $P not available after call to get_solr.sh"
            exit 2
        fi
    fi
}

function zoo() {
    local ZPACK="$1"
    local FOLDER=`echo $ZPACK | sed -e 's/.gz$//' -e 's/.tar$//' -e 's/.tgz//'`
    echo "  - Installing ZooKeeper ensemble of size $ZOOS"
    tar -xzovf ../../cache/$ZPACK > /dev/null
    local ZPORT=$ZOO_BASE_PORT
    
    for Z in `seq 1 $ZOOS`; do
        if [ ! -d zoo$Z ]; then
            echo "     - Copying ZooKeeper files for instance $Z"
            cp -r $FOLDER zoo$Z
        else
            echo "   - ZooKeeper files for instance $Z already exists"
        fi
        local ZCONF="zoo$Z/conf/zoo.cfg"
        if [ ! -s "$ZCONF" ]; then
            echo "     - Creating new setup for ZooKeeper $Z"
            echo "dataDir=`pwd`/zoo$Z/data" >> "$ZCONF"
            echo "clientPort=$ZPORT" >> "$ZCONF"
        else
            echo "     - ZooKeeper $Z already configured"
        fi
        local ZPORT=$(( ZPORT + 1 ))
    done
}

function solr() {
    local SPACK="$1"
    local FOLDER=`echo $SPACK | sed -e 's/[.]gz$//' -e 's/[.]tar$//' -e 's/[.]tgz//'`
    echo "  - Installing $SOLRS Solrs"
    tar -xzovf ../../cache/$SPACK > /dev/null
    if [ solr-* != $FOLDER ]; then
        mv solr-* $FOLDER
    fi
    
    if [ "." == ".`echo \" 5.5.3 6.3.0 trunk trunk-7521 \" | grep \" $DEST \"`" ]; then
        # We inject the JARs into the WAR to avoid fiddling with solrconfig.xml
        pushd $FOLDER/example/webapps/ > /dev/null
        if [ ! "." == ".$SPARSE_WAR" ]; then
            echo "     - Using sparse Solr WAR as Solr $VERSION"
            cp ../../../../../cache/$SPARSE_WAR solr.war
        fi
        mkdir -p WEB-INF/lib/
        cp ../../dist/solr-analysis-extras-*.jar WEB-INF/lib/
        cp ../../contrib/analysis-extras/lucene-libs/lucene-analyzers-icu-*.jar WEB-INF/lib/
        cp ../../contrib/analysis-extras/lib/icu4j*.jar WEB-INF/lib/
        echo "     - Patching Solr $VERSION WAR with needed JARs"
        zip solr.war WEB-INF > /dev/null
#        rm -r WEB_INF/
        popd > /dev/null
    fi
    
    for S in `seq 1 $SOLRS`; do
        if [ ! -d solr$S ]; then
            echo "     - Copying Solr files for instance $S"
            cp -r $FOLDER solr$S

            # The three libraries below are needed for collator sorting
            if [ ! "." == ".`echo \" 5.5.3 6.3.0 trunk trunk-7521 \" | grep \" $DEST \"`" ]; then
                local SOLR_LIB=solr$S/server/solr/lib/
                mkdir -p $SOLR_LIB
                cp $FOLDER/dist/solr-analysis-extras-*.jar $SOLR_LIB
                cp $FOLDER/contrib/analysis-extras/lucene-libs/lucene-analyzers-icu-*.jar $SOLR_LIB
                cp $FOLDER/contrib/analysis-extras/lib/icu4j*.jar $SOLR_LIB
            fi
        else
            echo "     - Solr $S already exists"
        fi
    done
}

function install() {
    local VERSION="$1"

    # Shared setup
    mkdir -p cloud
    DEST=$VERSION
    if [ -d cloud/$DEST ]; then
        echo "Solr $DEST already installed"
        return
    fi
    echo "- Installing SolrCloud $DEST"
    if [ $VERSION == 4.10.4-sparse ]; then
        SPARSE_WAR=sparse-4.10.war
        VERSION=4.10.4
    fi
    SPACK=solr-${VERSION}.tgz
    ZPACK=`basename "$ZOO_URL"`
    check_package $SPACK
    check_package $ZPACK
    echo "  - Source packages: $SPACK and $ZPACK"
    mkdir -p cloud/$DEST
    pushd cloud/$DEST > /dev/null
    zoo $ZPACK

    # Version specific parts
    
    if [ ! "." == ".`echo \" 4.10.4-sparse 4.10.4 5.5.3 6.3.0 trunk trunk-7521 \" | grep \" $DEST \"`" ]; then
        solr $SPACK
        popd > /dev/null # cloud/$DEST
        return
    fi

    >&2 echo "Error: Support for Solr version '$DEST' has not been implemented yet"
    usage 1
}

for V in $@; do
    install $V
done

popd > /dev/null # pwd