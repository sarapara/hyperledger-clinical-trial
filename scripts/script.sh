#!/bin/bash

CHANNEL_NAME="$1"
DELAY="$2"
LANGUAGE="$3"
TIMEOUT="$4"
CC_SRC_PATH="$5"
CC_NAME="$6"
: ${CHANNEL_NAME:="drugachannel"}
: ${DELAY:="3"}
: ${LANGUAGE:="node"}
: ${TIMEOUT:="10"}
: ${CC_SRC_PATH:="/opt/gopath/src/github.com/chaincode/druga/node/"}
: ${CC_NAME:="ccone"}
LANGUAGE=`echo "$LANGUAGE" | tr [:upper:] [:lower:]`
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/consilx.com/orderers/orderer.consilx.com/msp/tlscacerts/tlsca.consilx.com-cert.pem

echo "Channel name : $CHANNEL_NAME & CC_SRC_PATH: $CC_SRC_PATH & CC_NAME: $CC_NAME"

# import utils
. scripts/utils.sh

#create the channel
function createChannel() {
	setGlobals 0 2

	echo $CORE_PEER_TLS_ENABLED
	echo $CORE_PEER_MSPCONFIGPATH
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer channel create -o orderer.consilx.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/$CHANNEL_NAME.tx >&log.txt
		res=$?
                set +x
	else
				set -x
		peer channel create -o orderer.consilx.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/$CHANNEL_NAME.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		res=$?
				set +x
	fi
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

joinChannel () {
	declare -a arr=(1 2)
	if [ "$CHANNEL_NAME" == "verificationchannel" ]; then
			arr=(2)
  fi
	for org in "${arr[@]}"; do
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
		peer channel update -o orderer.consilx.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/$CHANNEL_NAME-${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
		res=$?
                set +x
  else
                set -x
		peer channel update -o orderer.consilx.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/$CHANNEL_NAME-${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		res=$?
                set +x
  fi
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	sleep $DELAY
	echo
}
installChaincode () {
	PEER=$1
	ORG=$2
	setGlobals $PEER $ORG
	VERSION=${3:-1.0}
        set -x
	peer chaincode install -n $CC_NAME -v ${VERSION} -l ${LANGUAGE} -p ${CC_SRC_PATH} >&log.txt
	res=$?
        set +x
	cat log.txt
	verifyResult $res "Chaincode installation on peer${PEER}.org${ORG} has failed (Org1 = pfizer, Org2 = manipalhospital)"
	echo "===================== Chaincode is installed on peer${PEER}.org${ORG} ===================== "
	echo
}

instantiateChaincode () {
	PEER=$1
	ORG=$2
	setGlobals $PEER $ORG
	VERSION=${3:-1.0}

	if [ "$CHANNEL_NAME" == "verificationchannel" ]; then
			endorsement="OR ('ManipalHospitalMSP.peer')";
	else
		endorsement="OR ('PfizerMSP.peer','ManipalHospitalMSP.peer')";
  fi
	# while 'peer chaincode' command can get the orderer endpoint from the peer
	# (if join was successful), let's supply it directly as we know it using
	# the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer chaincode instantiate -o orderer.consilx.com:7050 -C $CHANNEL_NAME -n $CC_NAME -l ${LANGUAGE} -v ${VERSION} -c '{"Args":["init"]}' >&log.txt
		res=$?
                set +x
	else
                set -x
		peer chaincode instantiate -o orderer.consilx.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -l ${LANGUAGE} -v 1.0 -c '{"Args":["init"]}' >&log.txt
		res=$?
                set +x
	fi
	sleep $DELAY
	cat log.txt

	verifyResult $res "Chaincode instantiation on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' failed (Org1 = pfizer, Org2 = manipalhospital)"
	echo "===================== Chaincode is instantiated on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
	echo
}

chaincodeQuery () {
  PEER=$1
  ORG=$2


  setGlobals $PEER $ORG

  echo "===================== Querying on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME'...(Org1 = pfizer, Org2 = manipalhospital) ===================== "
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep $DELAY
     echo "Attempting to Query peer${PEER}.org${ORG} ...$(($(date +%s)-starttime)) secs"
     set -x
     peer chaincode query -C $CHANNEL_NAME -n $CC_NAME -c "$3" >&log.txt
	 res=$?
     set +x
     test $res -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
		 echo "Value = $VALUE"
     let rc=0

  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query successful on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on peer${PEER}.org${ORG} is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
	exit 1
  fi
}


chaincodeInvoke () {
	PEER=$1
	ORG=$2
	ARGS=$3
	setGlobals $PEER $ORG
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
                set -x
		peer chaincode invoke -o orderer.consilx.com:7050 -C $CHANNEL_NAME -n $CC_NAME -c "$ARGS" >&log.txt
		res=$?
                set +x
	else
                set -x
		peer chaincode invoke -o orderer.consilx.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n $CC_NAME -c "$ARGS" >&log.txt
		res=$?
                set +x
	fi
	cat log.txt
	verifyResult $res "Invoke execution on peer${PEER}.org${ORG} failed "
	echo "===================== Invoke transaction on peer${PEER}.org${ORG} on channel '$CHANNEL_NAME' is successful ===================== "
	echo

}


#Create the network using docker compose
if [ "${CHANNEL_NAME}" == "verificationchannel" ]; then
	## Create channel
	echo "Creating channel..."
	createChannel

	## Join all the peers to the channel
	echo "Having all peers join the channel..."
	joinChannel

	## Set the anchor peers for each org in the channel
	echo "Updating anchor peers for manipalhospital org..."
	updateAnchorPeers 0 2

	## Install chaincode on peer0.pfizer and peer0.manipalhospital
	echo "Install chaincode on peer0.manipalhospital..."
	installChaincode 0 2

	# Instantiate chaincode on peer0.manipalhospital
	echo "Instantiating chaincode on peer0.manipalhospital..."
	instantiateChaincode 0 2

	# Invoke chaincode on peer0.manipalhospital
	echo "Sending invoke transaction on peer0.manipalhospital..."
	chaincodeInvoke 0 2 '{"Args":["initParticipant","p1@gmail.com","John Doe"]}'
	sleep $DELAY

	# Invoke chaincode on peer0.manipalhospital
	echo "Sending invoke transaction on peer0.manipalhospital..."
	chaincodeInvoke 0 2 '{"Args":["verifyParticipant","p1@gmail.com"]}'
	sleep $DELAY
	# Query chaincode on peer0.pfizer
	echo "Querying chaincode on peer0.manipalhospital..."
	chaincodeQuery 0 2 '{"Args":["readObject","p1@gmail.com"]}'
elif [ "${CHANNEL_NAME}" == "drugachannel" ]; then
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

	# Install chaincode on peer0.pfizer and peer0.manipalhospital
	echo "Installing chaincode on peer0.pfizer..."
	installChaincode 0 1
	echo "Install chaincode on peer0.manipalhospital..."
	installChaincode 0 2

	# Instantiate chaincode on peer0.manipalhospital
	echo "Instantiating chaincode on peer0.manipalhospital..."
	instantiateChaincode 0 2


	# Instantiate chaincode on peer0.manipalhospital
	# echo "Instantiating chaincode on peer0.pfizer..."
	# instantiateChaincode 0 1

	# Invoke chaincode on peer0.pfizer and peer0.manipalhospital
	echo "Add Doctor "
	chaincodeInvoke 0 2 '{"Args":["initDoctor","d1@mh.org","d1"]}'
sleep $DELAY
# Query chaincode on peer0.pfizer
echo "Querying chaincode on peer0.manipalhospital..."
chaincodeQuery 0 2 '{"Args":["readObject","d1@mh.org"]}'

	echo "Add Patient"
	chaincodeInvoke 0 2 '{"Args":["initPatient","p1@gmail.com","John Doe","d1@mh.org"]}'
sleep $DELAY
	echo "Setup Consent for Patient"
	chaincodeInvoke 0 2 '{"Args":["setupConsent","c1","d1@mh.org","p1@gmail.com"]}'
sleep $DELAY
	echo "Patient provides consent"
	chaincodeInvoke 0 2 '{"Args":["provideConsent","c1","p1@gmail.com"]}'
sleep $DELAY
	echo "Doctor cosings consent"
	chaincodeInvoke 0 2 '{"Args":["coSignConsent","c1","d1@mh.org"]}'
sleep $DELAY
	# Query chaincode on peer0.pfizer
	echo "Querying chaincode on peer0.pfizer..."
	chaincodeQuery 0 2 '{"Args":["readObject","c1"]}'
else
  echo "===================== Failed!! Unknown channel - \"$CHANNEL_NAME\" ===================== "
  exit 1
fi


exit 0
