#!/bin/bash

CHANNEL_NAME="$1"
DELAY="$2"
LANGUAGE="$3"
TIMEOUT="$4"
: ${CHANNEL_NAME:="drugachannel"}
: ${DELAY:="3"}
: ${LANGUAGE:="node"}
: ${TIMEOUT:="10"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consilx.com/orderers/orderer.consilx.com/msp/tlscacerts/tlsca.consilx.com-cert.pem
PEER0_ORG1_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/pfizer.com/peers/peer0.pfizer.com/tls/ca.crt
PEER0_ORG2_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manipalhospital.org/peers/peer0.manipalhospital.org/tls/ca.crt



CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/node/"

echo "Channel name : "$CHANNEL_NAME

# import utils
. scripts/utils.sh

#create the channel
function createChannel() {
	setGlobals 0 1

	echo $CORE_PEER_TLS_ENABLED
	echo $CORE_PEER_MSPCONFIGPATH
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer channel create -o orderer.consilx.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx >&log.txt
		res=$?
                set +x
	else
				set -x
		peer channel create -o orderer.consilx.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		res=$?
				set +x
	fi
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

joinChannel () {
	for org in 1 2; do
	    for peer in 0; do
		joinChannelWithRetry $peer $org
		echo "===================== peer${peer}.org${org} joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep $DELAY
		echo
	    done
	done
}

updateAnchorPeers() {
  PEER=$1
  ORG=$2
  setGlobals $PEER $ORG

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer channel update -o orderer.consilx.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
		res=$?
                set +x
  else
                set -x
		peer channel update -o orderer.consilx.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		res=$?
                set +x
  fi
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	sleep $DELAY
	echo
}
## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for pfizer org..."
updateAnchorPeers 0 1
echo "Updating anchor peers for manipalhospital org..."
updateAnchorPeers 0 2

## Install chaincode on peer0.pfizer and peer0.manipalhospital
echo "Installing chaincode on peer0.pfizer..."
installChaincode 0 1
echo "Install chaincode on peer0.manipalhospital..."
installChaincode 0 2

# Instantiate chaincode on peer0.manipalhospital
echo "Instantiating chaincode on peer0.manipalhospital..."
instantiateChaincode 0 2


# Instantiate chaincode on peer0.manipalhospital
echo "Instantiating chaincode on peer0.pfizer..."
instantiateChaincode 0 1



# Invoke chaincode on peer0.pfizer and peer0.manipalhospital
echo "Sending invoke transaction on peer0.pfizer peer0.manipalhospital..."
chaincodeInvoke 0 1

# Query chaincode on peer0.pfizer
echo "Querying chaincode on peer0.pfizer..."
chaincodeQuery 0 2 d1
exit 0
