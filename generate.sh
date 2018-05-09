#!/bin/bash

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

# Generates Org certs using cryptogen tool
function generateCerts (){
  which cryptogen
  if [ "$?" -ne 0 ]; then
    echo "cryptogen tool not found. exiting"
    exit 1
  fi
  echo
  echo "##########################################################"
  echo "##### Generate certificates using cryptogen tool #########"
  echo "##########################################################"

  if [ -d "crypto-config" ]; then
    rm -Rf crypto-config
  fi
  set -x
  cryptogen generate --config=./crypto-config.yaml
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate certificates..."
    exit 1
  fi
  echo
}

# Generate orderer genesis block, channel configuration transaction and
# anchor peer update transactions
function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    echo "configtxgen tool not found. exiting"
    exit 1
  fi

  echo "##########################################################"
  echo "#########  Generating Orderer Genesis block ##############"
  echo "##########################################################"
  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  set -x
  configtxgen -profile ConsilXOrdererGenesis -outputBlock ./channel-artifacts/genesis.block
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate orderer genesis block..."
    exit 1
  fi
  echo
  echo "#################################################################"
  echo "### Generating channel configuration transaction 'channel.tx' ###"
  echo "#################################################################"
  set -x
  configtxgen -profile DrugAPfizerChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate channel configuration transaction..."
    exit 1
  fi

  echo
  echo "#################################################################"
  echo "#######    Generating anchor peer update for PfizerOrg   ##########"
  echo "#################################################################"
  set -x
  configtxgen -profile DrugAPfizerChannel -outputAnchorPeersUpdate ./channel-artifacts/PfizerMSPanchors.tx -channelID $CHANNEL_NAME -asOrg PfizerOrg
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate anchor peer update for PfizerOrg..."
    exit 1
  fi

  echo
  echo "#################################################################"
  echo "#######    Generating anchor peer update for ManipalHospitalOrg   ##########"
  echo "#################################################################"
  set -x
  configtxgen -profile DrugAPfizerChannel -outputAnchorPeersUpdate \
  ./channel-artifacts/ManipalHospitalMSPanchors.tx -channelID $CHANNEL_NAME -asOrg ManipalHospitalOrg
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate anchor peer update for ManipalHospitalOrg..."
    exit 1
  fi
  echo
}

# Obtain the OS and Architecture string that will be used to select the correct
# native binaries for your platform
OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
# timeout duration - the duration the CLI should wait for a response from
# another container before giving up
CLI_TIMEOUT=10
# default for delay between commands
CLI_DELAY=3
# channel name defaults to "mychannel"
CHANNEL_NAME="drugAchannel"

while getopts "h?m:c:t:d:f:s:l:i:" opt; do
  case "$opt" in
    h|\?)
      printHelp
      exit 0
    ;;
    c)  CHANNEL_NAME=$OPTARG
    ;;
    t)  CLI_TIMEOUT=$OPTARG
    ;;
    d)  CLI_DELAY=$OPTARG
    ;;
  esac
done

# Announce what was requested
echo "${EXPMODE} with channel '${CHANNEL_NAME}' and CLI timeout of '${CLI_TIMEOUT}' seconds and CLI delay of '${CLI_DELAY}' seconds"

# ask for confirmation to proceed
askProceed

mkdir -p channel-artifacts
rm -fr channel-artifacts/*
rm -fr crypto-config/*

generateCerts
generateChannelArtifacts
