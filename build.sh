#!/bin/bash

JETTY_VERSION=7.4.2.v20110526
EXIST_REV=14611
DIGILIB_CHANGESET=cbfc94584d3b
DIGILIB_LOC=http://hg.berlios.de/repos/digilib/archive/$DIGILIB_CHANGESET.tar.bz2

SCRIPT=`readlink -f $0`
SCRIPTLOC=`dirname $SCRIPT`

BUILDLOC=$SCRIPTLOC/build
LOGDIR=$BUILDLOC/log

if [ ! -d $BUILDLOC ]; then
    mkdir $BUILDLOC
fi

if [ ! -d $LOGDIR ]; then
    mkdir $LOGDIR
fi

# backup old build
if [ -e $BUILDLOC/sade ]; then
    mv $BUILDLOC/sade $BUILDLOC/sade-bak-$(date +%F_%H-%M-%S)
fi

#####
#
# JETTY
# get jetty
#
#####
echo "[SADE BUILD] get and unpack jetty"
cd $BUILDLOC

if [ ! -e $BUILDLOC/jetty-distribution-$JETTY_VERSION.tar.gz ]; then
    wget http://download.eclipse.org/jetty/$JETTY_VERSION/dist/jetty-distribution-$JETTY_VERSION.tar.gz -O $BUILDLOC/jetty-distribution-$JETTY_VERSION.tar.gz
fi

tar xfz jetty-distribution-$JETTY_VERSION.tar.gz
mv jetty-distribution-$JETTY_VERSION sade


######
#
# EXIST
# checkout and build exist
#
# TODO: check if rev is same as checked out, if yes, no rebuild
# 
######
echo "[SADE BUILD] checkout and build eXist"
cd $BUILDLOC

BUILD_EXIST=true

if [ ! -e $BUILDLOC/exist-trunk ]; then
    svn co https://exist.svn.sourceforge.net/svnroot/exist/trunk/eXist -r $EXIST_REV exist-trunk
else 
    LOCAL_EXIST_REV=`LANG=C svn info exist-trunk/ |grep Revision | awk '{print $2}'`
    if [ $EXIST_REV != $LOCAL_EXIST_REV ]; then
        svn up -r $EXIST_REV exist-trunk
    else
        # revision did not change, and exist*.war is in place no need to rebuild
        if [ -e $BUILDLOC/exist-trunk/dist/exist*.war ];then
            echo "[SADE BUILD] found already build exist.war with correct revision"
            BUILD_EXIST=false
        fi
    fi
fi

if [ $BUILD_EXIST == true ]; then
    echo "[SADE BUILD] building eXist"
    # we want xslfo, a diff/patch may be better than sed here
    sed -i 's/include.module.xslfo = false/include.module.xslfo = true/g' exist-trunk/extensions/build.properties

    cd exist-trunk
    ./build.sh clean 
    ./build.sh 
    ./build.sh jnlp-sign-all dist-war
else
    echo "[SADE BUILD] everything in place, no need to rebuild eXist"
fi

cd $BUILDLOC/sade/webapps
mkdir exist
cd exist
unzip -q $BUILDLOC/exist-trunk/dist/exist*.war


#####
#
# DIGILIB
#
#####
echo "[SADE BUILD] get and build digilib"
cd $BUILDLOC

if [ ! -e $BUILDLOC/$DIGILIB_CHANGESET.tar.bz2 ]; then
    wget $DIGILIB_LOC -O $BUILDLOC/$DIGILIB_CHANGESET.tar.bz2
fi

tar jxf $DIGILIB_CHANGESET.tar.bz2
cd digilib-$DIGILIB_CHANGESET

#mvn package -Dmaven.compiler.source=1.6 -Dmaven.compiler.target=1.6 -Ptext -Ppdf -Pservlet2 > $LOGDIR/digilib_build.log
mvn package -Dmaven.compiler.source=1.6 -Dmaven.compiler.target=1.6 -Ptext -Ppdf -Pservlet2

cd $BUILDLOC/sade/webapps
mkdir digilib
cd digilib
unzip -q $BUILDLOC/digilib-$DIGILIB_CHANGESET/webapp/target/digilib*.war

mkdir $BUILDLOC/sade/images

#####
#
# SADE Docroot
#
#####
echo "[SADE BUILD] install sade docroot"
cd $SCRIPTLOC

cp -r sade-resources/docroot $BUILDLOC/sade/docroot
mv $BUILDLOC/sade/contexts/test.xml $BUILDLOC/sade/contexts-available/
cp sade-resources/contexts/docroot.xml $BUILDLOC/sade/contexts/

mv $BUILDLOC/sade/webapps/exist/WEB-INF/conf.xml $BUILDLOC/sade/webapps/exist/WEB-INF/conf.xml.orig
cp sade-resources/exist-conf.xml $BUILDLOC/sade/webapps/exist/WEB-INF/conf.xml

####
#
# RESTORE sade xql to exist
# does not work yet, needs to fork jetty process and run restore, use restore.sh for now
##
echo "[SADE BUILD] restore sade db content to eXist"
echo "[SADE BUILD] starting sade"
cd $BUILDLOC/sade

java -jar start.jar & > $LOGDIR/sade_start.log 2>&1
SADE_PID=$!

sleep 10s
echo "[SADE BUILD] restoring backup"
cd $BUILDLOC/exist-trunk/
#java -jar start.jar backup -r $SCRIPTLOC/sade-resources/exist-backup.zip > $LOGDIR/exist_restore.log 2>&1
java -jar start.jar backup -r $SCRIPTLOC/sade-resources/exist-backup.zip

kill $SADE_PID

sleep 10s

echo "[SADE BUILD] done"
echo "[SADE BUILD] you may now go to $BUILDLOC/sade and run 'java -jar start.jar'"

