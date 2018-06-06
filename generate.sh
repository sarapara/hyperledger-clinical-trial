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

function replacePrivateKey () {

  ARCH=`uname -s | grep Darwin`
  if [ "$ARCH" == "Darwin" ]; then
    OPTS="-it"
  else
    OPTS="-i"
  fi

  # Copy the template to the file that will be modified to add the private key
  cp docker-compose-cli-template.yaml docker-compose-cli.yaml

  # The next steps will replace the template's contents with the
  # actual values of the private key file names for the two CAs.


  CURRENT_DIR=$PWD
  cd crypto-config/peerOrganizations/pfizer.com/ca/
  PRIV_KEY=$(ls *_sk)
  cd "$CURRENT_DIR"
  sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-cli.yaml
  cd crypto-config/peerOrganizations/manipalhospital.org/ca/
  PRIV_KEY=$(ls *_sk)
  cd "$CURRENT_DIR"
  sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-cli.yaml

  # If MacOSX, remove the temporary backup of the docker-compose file
  if [ "$ARCH" == "Darwin" ]; then
    rm docker-compose-cli.yamlt
  fi
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
  echo "### Generating channel configuration transaction 'drugachannel.tx' ###"
  echo "#################################################################"
  set -x
  configtxgen -profile DrugAChannel -outputCreateChannelTx ./channel-artifacts/drugachannel.tx -channelID $CHANNEL_NAME1
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate channel configuration transaction-$CHANNEL_NAME1..."
    exit 1
  fi
  echo
  echo "#################################################################"
  echo "### Generating channel configuration transaction 'verificationchannel.tx' ###"
  echo "#################################################################"
  set -x
  configtxgen -profile VerificationChannel -outputCreateChannelTx ./channel-artifacts/verificationchannel.tx -channelID $CHANNEL_NAME2
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate channel configuration transaction-$CHANNEL_NAME2..."
    exit 1
  fi

  echo
  echo "#################################################################"
  echo "#######    Generating anchor peer update for PfizerOrg for $CHANNEL_NAME1   ##########"
  echo "#################################################################"
  set -x
  configtxgen -profile DrugAChannel -outputAnchorPeersUpdate ./channel-artifacts/$CHANNEL_NAME1-PfizerMSPanchors.tx -channelID $CHANNEL_NAME1 -asOrg PfizerMSP
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate anchor peer update for PfizerOrg($CHANNEL_NAME1)..."
    exit 1
  fi

  echo
  echo "#################################################################"
  echo "#######    Generating anchor peer update for ManipalHospitalOrg for $CHANNEL_NAME1  ##########"
  echo "#################################################################"
  set -x
  configtxgen -profile DrugAChannel -outputAnchorPeersUpdate \
  ./channel-artifacts/$CHANNEL_NAME1-ManipalHospitalMSPanchors.tx -channelID $CHANNEL_NAME1 -asOrg ManipalHospitalMSP
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate anchor peer update for ManipalHospitalOrg($CHANNEL_NAME1)..."
    exit 1
  fi
  echo

  echo
  echo "#################################################################"
  echo "#######    Generating anchor peer update for PfizerOrg for $CHANNEL_NAME2   ##########"
  echo "#################################################################"
  set -x
  configtxgen -profile DrugAChannel -outputAnchorPeersUpdate ./channel-artifacts/$CHANNEL_NAME2-PfizerMSPanchors.tx -channelID $CHANNEL_NAME2 -asOrg PfizerMSP
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate anchor peer update for PfizerOrg($CHANNEL_NAME2)..."
    exit 1
  fi

  echo
  echo "#################################################################"
  echo "#######    Generating anchor peer update for ManipalHospitalOrg for $CHANNEL_NAME2  ##########"
  echo "#################################################################"
  set -x
  configtxgen -profile DrugAChannel -outputAnchorPeersUpdate \
  ./channel-artifacts/$CHANNEL_NAME2-ManipalHospitalMSPanchors.tx -channelID $CHANNEL_NAME2 -asOrg ManipalHospitalMSP
  res=$?
  set +x
  if [ $res -ne 0 ]; then
    echo "Failed to generate anchor peer update for ManipalHospitalOrg($CHANNEL_NAME2)..."
    exit 1
  fi
  echo
}

# channel name defaults to "drugachannel"
CHANNEL_NAME1="drugachannel"
CHANNEL_NAME2="verificationchannel"

# while getopts "h?m:c:t:d:f:s:l:i:" opt; do
#   case "$opt" in
#     h|\?)
#       printHelp
#       exit 0
#     ;;
#     c)  CHANNEL_NAME=$OPTARG
#     ;;
#   esac
# done

# Announce what was requested
echo "${EXPMODE} with channel '${CHANNEL_NAME1}' & '${CHANNEL_NAME2}'"

# ask for confirmation to proceed
askProceed

mkdir -p channel-artifacts
rm -rf channel-artifacts/*
rm -rf crypto-config/*
rm docker-compose-cli.yaml

generateCerts
replacePrivateKey
generateChannelArtifacts
