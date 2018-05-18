
NETWORK_NAME="$1"
DELAY=3
# ./cleanup.sh $NETWORK_NAME

# mkdir -p ./tmp/composer/pfizer
# mkdir -p ./tmp/composer/manipalhospital
mkdir -p ./tmp/composer/$NETWORK_NAME/pfizer
mkdir -p ./tmp/composer/$NETWORK_NAME/manipalhospital
echo "Setting up connection json file for composer to connect to the fabric ...."

cp ./$NETWORK_NAME-template.json ./$NETWORK_NAME.json
CURRENT_DIR=$PWD
echo "Setting up ca key for Pfizer in connection file ...."
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/peerOrganizations/pfizer.com/peers/peer0.pfizer.com/tls/ca.crt > ./tmp/composer/$NETWORK_NAME/pfizer/ca-pfizer.txt
cd ./tmp/composer/$NETWORK_NAME/pfizer
perl -pe 's/INSERT_ORG1_CA_CERT/`cat ca-pfizer.txt`/ge' -i ../../../../$NETWORK_NAME.json
cd "$CURRENT_DIR"
echo "Setting up ca key for ManipalHospital in connection file ...."
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/peerOrganizations/manipalhospital.org/peers/peer0.manipalhospital.org/tls/ca.crt > ./tmp/composer/$NETWORK_NAME/manipalhospital/ca-manipalhospital.txt
cd ./tmp/composer/$NETWORK_NAME/manipalhospital
perl -pe 's/INSERT_ORG2_CA_CERT/`cat ca-manipalhospital.txt`/ge' -i ../../../../$NETWORK_NAME.json
cd "$CURRENT_DIR"
echo "Setting up ca key for Orderer in connection file ...."
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/ordererOrganizations/consilx.com/orderers/orderer.consilx.com/tls/ca.crt > ./tmp/composer/$NETWORK_NAME/ca-orderer.txt
cd ./tmp/composer/$NETWORK_NAME/
perl -pe 's/INSERT_ORDERER_CA_CERT/`cat ca-orderer.txt`/ge' -i ../../../$NETWORK_NAME.json
cd "$CURRENT_DIR"

echo "Setting up Pfizer connection file ...."
cp ./$NETWORK_NAME.json ./tmp/composer/$NETWORK_NAME/pfizer/$NETWORK_NAME-pfizer.json
sed -it "s/INSERT_ORG_NAME/Pfizer/g" ./tmp/composer/$NETWORK_NAME/pfizer/$NETWORK_NAME-pfizer.json
rm -f ./tmp/composer/$NETWORK_NAME/pfizer/$NETWORK_NAME-pfizer.jsont

echo "Setting up ManipalHospital connection file ...."
cp ./$NETWORK_NAME.json ./tmp/composer/$NETWORK_NAME/manipalhospital/$NETWORK_NAME-manipalhospital.json
sed -it "s/INSERT_ORG_NAME/ManipalHospital/g" ./tmp/composer/$NETWORK_NAME/manipalhospital/$NETWORK_NAME-manipalhospital.json
rm -f ./tmp/composer/$NETWORK_NAME/manipalhospital/$NETWORK_NAME-manipalhospital.jsont

echo "Setting up endorsement-policy ...."
cp ./endorsement-policy.json ./tmp/composer/$NETWORK_NAME/endorsement-policy.json

echo "Copying Admin signature and keys for Pfizer ...."
export ORG1=../crypto-config/peerOrganizations/pfizer.com/users/Admin@pfizer.com/msp
cp -p $ORG1/signcerts/A*.pem ./tmp/composer/$NETWORK_NAME/pfizer
cp -p $ORG1/keystore/*_sk ./tmp/composer/$NETWORK_NAME/pfizer

echo "Copying Admin signature and keys for ManipalHospital ...."
export ORG2=../crypto-config/peerOrganizations/manipalhospital.org/users/Admin@manipalhospital.org/msp
cp -p $ORG2/signcerts/A*.pem ./tmp/composer/$NETWORK_NAME/manipalhospital
cp -p $ORG2/keystore/*_sk ./tmp/composer/$NETWORK_NAME/manipalhospital

echo "Creating PeerAdmin card for Pfizer ...."
composer card create -p ./tmp/composer/$NETWORK_NAME/pfizer/$NETWORK_NAME-pfizer.json -u PeerAdmin -c ./tmp/composer/$NETWORK_NAME/pfizer/Admin@pfizer.com-cert.pem -k ./tmp/composer/$NETWORK_NAME/pfizer/*_sk -r PeerAdmin -r ChannelAdmin -f PeerAdmin@$NETWORK_NAME-pfizer.card
sleep $DELAY
echo "Creating PeerAdmin card for ManipalHospital ...."
composer card create -p ./tmp/composer/$NETWORK_NAME/manipalhospital/$NETWORK_NAME-manipalhospital.json -u PeerAdmin -c ./tmp/composer/$NETWORK_NAME/manipalhospital/Admin@manipalhospital.org-cert.pem -k ./tmp/composer/$NETWORK_NAME/manipalhospital/*_sk -r PeerAdmin -r ChannelAdmin -f PeerAdmin@$NETWORK_NAME-manipalhospital.card
sleep $DELAY
echo "Importing PeerAdmin card for Pfizer ...."
composer card import -f PeerAdmin@$NETWORK_NAME-pfizer.card --card PeerAdmin@$NETWORK_NAME-pfizer
sleep $DELAY
echo "Importing   PeerAdmin card for ManipalHospital ...."
composer card import -f PeerAdmin@$NETWORK_NAME-manipalhospital.card --card PeerAdmin@$NETWORK_NAME-manipalhospital
sleep $DELAY

# echo "Creating business network archive file ...."
# composer archive create -t dir -n .

echo "Installing network for Pfizer ...."
composer network install --card PeerAdmin@$NETWORK_NAME-pfizer --archiveFile $NETWORK_NAME@0.0.1.bna
sleep $DELAY
echo "Installing network for ManipalHospital ...."
composer network install --card PeerAdmin@$NETWORK_NAME-manipalhospital --archiveFile $NETWORK_NAME@0.0.1.bna
sleep $DELAY

echo "Requesting admin identity's certificate and key for Pfizer ...."
composer identity request -c PeerAdmin@$NETWORK_NAME-pfizer -u admin -s adminpw -d pharmaadmin
sleep $DELAY
echo "Requesting admin identity's certificate and key for ManipalHospital ...."
composer identity request -c PeerAdmin@$NETWORK_NAME-manipalhospital -u admin -s adminpw -d siteadmin
sleep $DELAY

echo "Start composer business network ...."
composer network start -c PeerAdmin@$NETWORK_NAME-pfizer -n $NETWORK_NAME -V 0.0.1 -o endorsementPolicyFile=./tmp/composer/$NETWORK_NAME/endorsement-policy.json -A pharmaadmin -C pharmaadmin/admin-pub.pem -A siteadmin -C siteadmin/admin-pub.pem
sleep $DELAY



echo "Creating & Importing identity card for pharmaadmin(Pfizer) ...."
rm ./pharmaadmin@$NETWORK_NAME.card
composer card create -p ./tmp/composer/$NETWORK_NAME/pfizer/$NETWORK_NAME-pfizer.json -u pharmaadmin -n $NETWORK_NAME -c pharmaadmin/admin-pub.pem -k pharmaadmin/admin-priv.pem
sleep $DELAY
composer card import -f pharmaadmin@$NETWORK_NAME.card
sleep $DELAY

echo "Creating & Importing identity card for siteadmin(ManipalHospital) ...."
rm ./siteadmin@$NETWORK_NAME.card
composer card create -p ./tmp/composer/$NETWORK_NAME/manipalhospital/$NETWORK_NAME-manipalhospital.json -u siteadmin -n $NETWORK_NAME -c siteadmin/admin-pub.pem -k siteadmin/admin-priv.pem
sleep $DELAY
composer card import -f siteadmin@$NETWORK_NAME.card
sleep $DELAY

echo "Testing network through pharmaadmin ...."
composer network ping -c pharmaadmin@$NETWORK_NAME
sleep $DELAY
echo "Testing network through siteadmin ...."
composer network ping -c siteadmin@$NETWORK_NAME
sleep $DELAY
