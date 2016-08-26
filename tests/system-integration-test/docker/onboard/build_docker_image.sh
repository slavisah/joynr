#!/bin/bash

BUILDDIR=target
REPODIR=${HOME}/.m2/repository
DOCKER_REPOSITORY=
MAVENSETTINGS=${HOME}/.m2/settings.xml
BASE_DOCKER_IMAGE=joynr-runtime-environment-base:latest
CPP_BUILD_DOCKER_IMAGE=joynr-cpp-gcc:latest
JS_BUILD_DOCKER_IMAGE=joynr-javascript:latest
DOCKER_RUN_ADD_FLAGS=
JOBS=2

function print_usage {
	echo "
Usage: ./build_docker_image.sh [<options>]

Possible options:

--no-cpp-build: skip the clean / build of the joynr CPP framework
--no-cpp-test-build: skip building the sit-cpp-app
--no-node-test-build: skip building the sit-node-app
-r, --docker-repository <docker repository>: set the value of the DOCKER_REPOSITORY variable, determining
    where the cpp base image is pulled from.
--docker-run-flags <run flags>: add some additional flags required when calling docker (e.g. \"--sig-proxy -e DEV_UID=$(id -u)\")
--repo-dir <repository directory>: override the default maven repository directory
--maven-settings <maven settings file>: override the location of the default maven settings file
-j, --jobs <number of build jobs>: the number of build jobs used for parallel C++ builds.
-h, --help: print this information
"
}

while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		--no-cpp-build)
		NO_CPP_BUILD=true
		;;
		--no-cpp-test-build)
		NO_CPP_TEST_BUILD=true
		;;
		--no-node-test-build)
		NO_NODE_TEST_BUILD=true
		;;
		-r|--docker-repository)
		DOCKER_REPOSITORY="$2"
		shift
		;;
		--docker-run-flags)
		DOCKER_RUN_ADD_FLAGS="$2"
		shift
		;;
		--repo-dir)
		REPODIR="$2"
		shift
		;;
		--maven-settings)
		MAVENSETTINGS="$2"
		shift
		;;
		-j|--jobs)
		shift
		JOBS=$1
		;;
		-h|--help)
		print_usage
		exit 0
		;;
		*)
		echo "Unknown argument: $1"
		print_usage
		exit -1
		;;
	esac
	shift
done

function execute_in_docker {
	if [ -z "$2" ]; then
		DOCKERIMAGE=${CPP_BUILD_DOCKER_IMAGE}
	else
		DOCKERIMAGE=$2
	fi
	docker run --rm -t $DOCKER_RUN_ADD_FLAGS --privileged \
		-e http_proxy=$http_proxy \
		-e https_proxy=$https_proxy \
		-e no_proxy=$no_proxy \
		-v $(pwd)/../../../..:/data/src:Z \
		-v $MAVENSETTINGS:/home/joynr/.m2/settings.xml:z \
		-v $REPODIR:/home/joynr/.m2/repository:Z \
		-v $(pwd)/../../../../build:/data/build:Z \
		${DOCKER_REPOSITORY}${DOCKERIMAGE} \
		/bin/sh -c "$1"
}

#create build dir:
mkdir -p $(pwd)/../../../../build

if [ $NO_CPP_BUILD ]; then
	echo "Skipping C++ build ..."
else
	execute_in_docker "echo \"Generate joynr C++ API\" && cd /data/src && mvn clean install -P no-license-and-notice,no-java-formatter,no-checkstyle -DskipTests -am\
	--projects io.joynr:basemodel,io.joynr.tools.generator:dependency-libs,io.joynr.tools.generator:generator-framework,io.joynr.tools.generator:joynr-generator-maven-plugin,io.joynr.tools.generator:cpp-generator,io.joynr.cpp:libjoynr,io.joynr.tools.generator:joynr-generator-standalone"
	execute_in_docker "echo \"Building joynr c++\" && /data/src/docker/joynr-cpp-base/scripts/build/cpp-clean-build.sh --jobs ${JOBS} --enableclangformatter OFF --buildtests OFF 2>&1"
	execute_in_docker "echo \"Packaging joynr c++\" && /data/src/docker/joynr-cpp-base/scripts/build/cpp-build-rpm-package.sh --rpm-spec tests/system-integration-test/docker/onboard/joynr-without-test.spec 2>&1"
fi

if [ $NO_CPP_TEST_BUILD ]; then
	echo "Skipping C++ test build ..."
else
	execute_in_docker "echo \"Building C++ System Integration Tests\" && export JOYNR_INSTALL_DIR=/data/build/joynr && echo \"dir: \$JOYNR_INSTALL_DIR\" && /data/src/docker/joynr-cpp-base/scripts/build/cpp-build-tests.sh system-integration-test --jobs ${JOBS} --clangformatter OFF 2>&1"
fi

if [ $NO_NODE_TEST_BUILD ]; then
	echo "Skipping Node test build ..."
else
	execute_in_docker "echo \"Building sit node app\" && cd /data/src && mvn clean install -P javascript -am --projects io.joynr.javascript:libjoynr-js,io.joynr.tests:test-base,io.joynr.tests.system-integration-test:sit-node-app && cd tests/system-integration-test/sit-node-app && npm install"  $JS_BUILD_DOCKER_IMAGE
fi

if [ -d ${BUILDDIR} ]; then
	rm -Rf ${BUILDDIR}
fi
mkdir -p ${BUILDDIR}

cp -R ../../sit-node-app ${BUILDDIR}
cp -R ../../../../build/tests ${BUILDDIR}

# Find a file with a name which matches 'joynr-[version].rpm'
find  ../../../../build/joynr/package/RPM/x86_64/ -iregex ".*joynr-[0-9].*rpm" -exec cp {} $BUILDDIR/joynr.rpm \;

CURRENTDATE=`date`
cp onboard-cc-messaging.settings ${BUILDDIR}
cp run-onboard-sit.sh ${BUILDDIR}
cat > $BUILDDIR/Dockerfile <<-EOF
    FROM ${DOCKER_REPOSITORY}${BASE_DOCKER_IMAGE}

    RUN echo "current date: $CURRENTDATE" && curl www.google.de > /dev/null

    ###################################################
    # Install joynr
    ###################################################
    COPY joynr.rpm /tmp/joynr.rpm
    RUN dnf install -y \
        /tmp/joynr.rpm \
        && rm /tmp/joynr.rpm

    ###################################################
    # Copy C++ binaries
    ###################################################
    COPY tests /data/sit-cpp-app

    ###################################################
    # Copy sit-node-app
    ###################################################
    COPY sit-node-app /data/sit-node-app

    ###################################################
    # Copy run script
    ###################################################
    COPY onboard-cc-messaging.settings /data/onboard-cc-messaging.settings
    COPY run-onboard-sit.sh /data/run-onboard-sit.sh

    ENTRYPOINT ["sh", "-c", "\"/data/run-onboard-sit.sh\""]
EOF
chmod 666 $BUILDDIR/Dockerfile

echo "environment:" `env`
echo "docker build -t sit-node-and-cpp-apps:latest --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} --build-arg no_proxy=${no_proxy} $BUILDDIR"
docker build -t sit-node-and-cpp-apps:latest --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} --build-arg no_proxy=${no_proxy} $BUILDDIR

docker images | grep '<none' | awk '{print $3}' | xargs docker rmi -f 2>/dev/null
rm -Rf $BUILDDIR
