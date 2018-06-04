#!/bin/bash

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to SETUP channel ==========="
		echo
   		exit 1
	fi
}

setGlobals () {
	PEER=$1
	ORG=$2
	if [ $ORG -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="PfizerMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/pfizer.com/peers/peer0.pfizer.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/pfizer.com/users/Admin@pfizer.com/msp
		if [ $PEER -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.pfizer.com:7051
		else
			CORE_PEER_ADDRESS=peer1.pfizer.com:7051
		fi
	elif [ $ORG -eq 2 ] ; then
		CORE_PEER_LOCALMSPID="ManipalHospitalMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manipalhospital.org/peers/peer0.manipalhospital.org/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manipalhospital.org/users/Admin@manipalhospital.org/msp
		if [ $PEER -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.manipalhospital.org:7051
		else
			CORE_PEER_ADDRESS=peer1.manipalhospital.org:7051
		fi
	else
		echo "================== ERROR !!! ORG Unknown =================="
	fi

	env |grep CORE
}

## Sometimes Join takes time hence RETRY at least for 5 times
joinChannelWithRetry () {
	PEER=$1
	ORG=$2
	setGlobals $PEER $ORG

        set -x
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
        set +x
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
    echo "Org1 = pfizer, Org2 = manipalhospital"
		echo "peer${PEER}.org${ORG} failed to join the channel, Retry after $DELAY seconds"
		sleep $DELAY
		joinChannelWithRetry $PEER $ORG
	else
		COUNTER=1
	fi
	verifyResult $res "(Org1 = pfizer, Org2 = manipalhospital)After $MAX_RETRY attempts, peer${PEER}.org${ORG} has failed to Join the Channel"
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
