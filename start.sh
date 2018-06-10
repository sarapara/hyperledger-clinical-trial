# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform
OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=10
# default for delay between commands
CLI_DELAY=3
# channel name defaults to "drugachannel"
CHANNEL_NAME1="drugachannel"
CHANNEL_NAME2="verificationchannel"
# use this as the default docker-compose yaml definition
COMPOSE_FILE=docker-compose-cli.yaml
# use golang as the default language for chaincode
LANGUAGE=node
# default image tag
IMAGETAG="latest"

CC_SRC_PATH1="/opt/gopath/src/github.com/chaincode/druga/node/"
CC_SRC_PATH2="/opt/gopath/src/github.com/chaincode/verification/node/"

CC1="ccone"
CC2="cctwo"

# Ask user for confirmation to proceed
function askProceed () {
  read -p "Continue? [Y/n] " ans
  case "$ans" in
    y|Y|"" )
      echo "proceeding ..."
    ;;
    n|N )
      echo "exiting..."
      exit 1
    ;;
    * )
      echo "invalid response"
      askProceed
    ;;
  esac
}

# Versions of fabric known not to work with this release of first-network
BLACKLISTED_VERSIONS="^1\.0\. ^1\.1\.0-preview ^1\.1\.0-alpha"

# Do some basic sanity checking to make sure that the appropriate versions of fabric
# binaries/images are available.  In the future, additional checking for the presence
# of go or other items could be added.
function checkPrereqs() {
  # Note, we check configtxlator externally because it does not require a config file, and peer in the
  # docker image because of FAB-8551 that makes configtxlator return 'development version' in docker
  LOCAL_VERSION=$(configtxlator version | sed -ne 's/ Version: //p')
  DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:$IMAGETAG peer version | sed -ne 's/ Version: //p'|head -1)

  echo "LOCAL_VERSION=$LOCAL_VERSION"
  echo "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ] ; then
     echo "=================== WARNING ==================="
     echo "  Local fabric binaries and docker images are  "
     echo "  out of  sync. This may cause problems.       "
     echo "==============================================="
  fi

  for UNSUPPORTED_VERSION in $BLACKLISTED_VERSIONS ; do
     echo "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
     if [ $? -eq 0 ] ; then
       echo "ERROR! Local Fabric binary version of $LOCAL_VERSION does not match this newer version of ctn and is unsupported. Either move to a later version of Fabric or checkout an earlier version of fabric-samples."
       exit 1
     fi

     echo "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
     if [ $? -eq 0 ] ; then
       echo "ERROR! Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match this newer version of ctn and is unsupported. Either move to a later version of Fabric or checkout an earlier version of fabric-samples."
       exit 1
     fi
  done
}

# start the network.
function networkUp () {
  checkPrereqs
  IMAGE_TAG=$IMAGETAG docker-compose --log-level ERROR -f $COMPOSE_FILE up -d 2>&1

  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Unable to start network"
    exit 1
  fi
  # now run the end to end script
  docker exec cli scripts/script.sh $CHANNEL_NAME2 $CLI_DELAY $LANGUAGE $CLI_TIMEOUT $CC_SRC_PATH2 $CC2
  docker exec cli scripts/script.sh $CHANNEL_NAME1 $CLI_DELAY $LANGUAGE $CLI_TIMEOUT $CC_SRC_PATH1 $CC1

  if [ $? -ne 0 ]; then
    echo "ERROR !!!! Test failed"
    exit 1
  fi
}

# Announce what was requested
echo "${EXPMODE} with channel '${CHANNEL_NAME2}' and CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds"

# ask for confirmation to proceed
askProceed

# start network
networkUp
