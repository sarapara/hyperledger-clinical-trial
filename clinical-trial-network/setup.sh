
./cleanup.sh

mkdir -p ./tmp/composer/pfizer
mkdir -p ./tmp/composer/manipalhospital

echo "Setting up connection json file for composer to connect to the fabric ...."

cp ./clinical-trial-network-template.json ./clinical-trial-network.json
CURRENT_DIR=$PWD
echo "Setting up ca key for Pfizer in connection file ...."
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/peerOrganizations/pfizer.com/peers/peer0.pfizer.com/tls/ca.crt > ./tmp/composer/pfizer/ca-pfizer.txt
cd ./tmp/composer/pfizer
perl -pe 's/INSERT_ORG1_CA_CERT/`cat ca-pfizer.txt`/ge' -i ../../../clinical-trial-network.json
cd "$CURRENT_DIR"
echo "Setting up ca key for ManipalHospital in connection file ...."
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/peerOrganizations/manipalhospital.org/peers/peer0.manipalhospital.org/tls/ca.crt > ./tmp/composer/manipalhospital/ca-manipalhospital.txt
cd ./tmp/composer/manipalhospital
perl -pe 's/INSERT_ORG2_CA_CERT/`cat ca-manipalhospital.txt`/ge' -i ../../../clinical-trial-network.json
cd "$CURRENT_DIR"
echo "Setting up ca key for Orderer in connection file ...."
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/ordererOrganizations/consilx.com/orderers/orderer.consilx.com/tls/ca.crt > ./tmp/composer/ca-orderer.txt
cd ./tmp/composer
perl -pe 's/INSERT_ORDERER_CA_CERT/`cat ca-orderer.txt`/ge' -i ../../clinical-trial-network.json
cd "$CURRENT_DIR"

echo "Setting up Pfizer connection file ...."
cp ./clinical-trial-network.json ./tmp/composer/pfizer/clinical-trial-network-pfizer.json
sed -it "s/INSERT_ORG_NAME/Pfizer/g" ./tmp/composer/pfizer/clinical-trial-network-pfizer.json
rm -f ./tmp/composer/pfizer/clinical-trial-network-pfizer.jsont

echo "Setting up ManipalHospital connection file ...."
cp ./clinical-trial-network.json ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.json
sed -it "s/INSERT_ORG_NAME/ManipalHospital/g" ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.json
rm -f ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.jsont

echo "Setting up endorsement-policy ...."
cp ./endorsement-policy.json ./tmp/composer/endorsement-policy.json

echo "Copying Admin signature and keys for Pfizer ...."
export ORG1=../crypto-config/peerOrganizations/pfizer.com/users/Admin@pfizer.com/msp
cp -p $ORG1/signcerts/A*.pem ./tmp/composer/pfizer
cp -p $ORG1/keystore/*_sk ./tmp/composer/pfizer

echo "Copying Admin signature and keys for ManipalHospital ...."
export ORG2=../crypto-config/peerOrganizations/manipalhospital.org/users/Admin@manipalhospital.org/msp
cp -p $ORG2/signcerts/A*.pem ./tmp/composer/manipalhospital
cp -p $ORG2/keystore/*_sk ./tmp/composer/manipalhospital

echo "Creating PeerAdmin card for Pfizer ...."
composer card create -p ./tmp/composer/pfizer/clinical-trial-network-pfizer.json -u PeerAdmin -c ./tmp/composer/pfizer/Admin@pfizer.com-cert.pem -k ./tmp/composer/pfizer/*_sk -r PeerAdmin -r ChannelAdmin -f PeerAdmin@clinical-trial-network-pfizer.card
sleep $DELAY
echo "Creating PeerAdmin card for ManipalHospital ...."
composer card create -p ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.json -u PeerAdmin -c ./tmp/composer/manipalhospital/Admin@manipalhospital.org-cert.pem -k ./tmp/composer/manipalhospital/*_sk -r PeerAdmin -r ChannelAdmin -f PeerAdmin@clinical-trial-network-manipalhospital.card
sleep $DELAY
echo "Importing PeerAdmin card for Pfizer ...."
composer card import -f PeerAdmin@clinical-trial-network-pfizer.card --card PeerAdmin@clinical-trial-network-pfizer
sleep $DELAY
echo "Importing   PeerAdmin card for ManipalHospital ...."
composer card import -f PeerAdmin@clinical-trial-network-manipalhospital.card --card PeerAdmin@clinical-trial-network-manipalhospital
sleep $DELAY

# echo "Creating business network archive file ...."
# composer archive create -t dir -n .

echo "Installing network for Pfizer ...."
composer network install --card PeerAdmin@clinical-trial-network-pfizer --archiveFile clinical-trial-network@0.0.1.bna
sleep $DELAY
echo "Installing network for ManipalHospital ...."
composer network install --card PeerAdmin@clinical-trial-network-manipalhospital --archiveFile clinical-trial-network@0.0.1.bna
sleep $DELAY

echo "Requesting admin identity's certificate and key for Pfizer ...."
composer identity request -c PeerAdmin@clinical-trial-network-pfizer -u admin -s adminpw -d pharmaadmin
sleep $DELAY
echo "Requesting admin identity's certificate and key for ManipalHospital ...."
composer identity request -c PeerAdmin@clinical-trial-network-manipalhospital -u admin -s adminpw -d siteadmin
sleep $DELAY

echo "Start composer business network ...."
composer network start -c PeerAdmin@clinical-trial-network-pfizer -n clinical-trial-network -V 0.0.1 -o endorsementPolicyFile=./tmp/composer/endorsement-policy.json -A pharmaadmin -C pharmaadmin/admin-pub.pem -A siteadmin -C siteadmin/admin-pub.pem
sleep $DELAY



echo "Creating & Importing identity card for pharmaadmin(Pfizer) ...."
rm ./pharmaadmin@clinical-trial-network.card
composer card create -p ./tmp/composer/pfizer/clinical-trial-network-pfizer.json -u pharmaadmin -n clinical-trial-network -c pharmaadmin/admin-pub.pem -k pharmaadmin/admin-priv.pem
sleep $DELAY
composer card import -f pharmaadmin@clinical-trial-network.card
sleep $DELAY

echo "Creating & Importing identity card for siteadmin(ManipalHospital) ...."
rm ./siteadmin@clinical-trial-network.card
composer card create -p ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.json -u siteadmin -n clinical-trial-network -c siteadmin/admin-pub.pem -k siteadmin/admin-priv.pem
sleep $DELAY
composer card import -f siteadmin@clinical-trial-network.card
sleep $DELAY

echo "Testing network through pharmaadmin ...."
composer network ping -c pharmaadmin@clinical-trial-network
sleep $DELAY
echo "Testing network through siteadmin ...."
composer network ping -c siteadmin@clinical-trial-network
sleep $DELAY
