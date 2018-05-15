composer card delete -c  PeerAdmin@clinical-trial-network-pfizer
composer card delete -c  PeerAdmin@clinical-trial-network-manipalhospital
composer card delete -c  pharmaadmin@clinical-trial-network
composer card delete -c  siteadmin@clinical-trial-network
rm -rf siteadmin
rm -rf pharmaadmin

rm -fr $HOME/.composer
rm -rf ./tmp/composer/pfizer
rm -rf ./tmp/composer/manipalhospital
rm ./clinical-trial-network.json
rm -f *.card
rm ./tmp/composer/ca-orderer.txt

mkdir -p ./tmp/composer/pfizer
mkdir -p ./tmp/composer/manipalhospital

cp ./clinical-trial-network-template.json ./clinical-trial-network.json

awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/peerOrganizations/pfizer.com/peers/peer0.pfizer.com/tls/ca.crt > ./tmp/composer/pfizer/ca-pfizer.txt

cat ./tmp/composer/pfizer/ca-pfizer.txt |pbcopy

***replace clinical-trial-network.json

awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/peerOrganizations/manipalhospital.org/peers/peer0.manipalhospital.org/tls/ca.crt > ./tmp/composer/manipalhospital/ca-manipalhospital.txt

cat ./tmp/composer/manipalhospital/ca-manipalhospital.txt |pbcopy

***replace clinical-trial-network.json

awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ../crypto-config/ordererOrganizations/consilx.com/orderers/orderer.consilx.com/tls/ca.crt > ./tmp/composer/ca-orderer.txt

cat ./tmp/composer/ca-orderer.txt |pbcopy

***replace clinical-trial-network.json

cp ./clinical-trial-network.json ./tmp/composer/pfizer/clinical-trial-network-pfizer.json
cp ./clinical-trial-network.json ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.json
cp ./endorsement-policy.json ./tmp/composer/endorsement-policy.json

sed -it "s/INSERT_ORG_NAME/Pfizer/g" ./tmp/composer/pfizer/clinical-trial-network-pfizer.json
rm -f ./tmp/composer/pfizer/clinical-trial-network-pfizer.jsont
sed -it "s/INSERT_ORG_NAME/ManipalHospital/g" ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.json
rm -f ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.jsont

export ORG1=../crypto-config/peerOrganizations/pfizer.com/users/Admin@pfizer.com/msp
cp -p $ORG1/signcerts/A*.pem ./tmp/composer/pfizer
cp -p $ORG1/keystore/*_sk ./tmp/composer/pfizer

export ORG2=../crypto-config/peerOrganizations/manipalhospital.org/users/Admin@manipalhospital.org/msp
cp -p $ORG2/signcerts/A*.pem ./tmp/composer/manipalhospital
cp -p $ORG2/keystore/*_sk ./tmp/composer/manipalhospital

composer card create -p ./tmp/composer/pfizer/clinical-trial-network-pfizer.json -u PeerAdmin -c ./tmp/composer/pfizer/Admin@pfizer.com-cert.pem -k ./tmp/composer/pfizer/*_sk -r PeerAdmin -r ChannelAdmin -f PeerAdmin@clinical-trial-network-pfizer.card

composer card create -p ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.json -u PeerAdmin -c ./tmp/composer/manipalhospital/Admin@manipalhospital.org-cert.pem -k ./tmp/composer/manipalhospital/*_sk -r PeerAdmin -r ChannelAdmin -f PeerAdmin@clinical-trial-network-manipalhospital.card

composer card import -f PeerAdmin@clinical-trial-network-pfizer.card --card PeerAdmin@clinical-trial-network-pfizer
composer card import -f PeerAdmin@clinical-trial-network-manipalhospital.card --card PeerAdmin@clinical-trial-network-manipalhospital

composer archive create -t dir -n .

composer network install --card PeerAdmin@clinical-trial-network-pfizer --archiveFile clinical-trial-network@0.0.1.bna

composer network install --card PeerAdmin@clinical-trial-network-manipalhospital --archiveFile clinical-trial-network@0.0.1.bna

composer identity request -c PeerAdmin@clinical-trial-network-pfizer -u admin -s adminpw -d pharmaadmin
composer identity request -c PeerAdmin@clinical-trial-network-manipalhospital -u admin -s adminpw -d siteadmin

composer network start -c PeerAdmin@clinical-trial-network-pfizer -n clinical-trial-network -V 0.0.1 -o endorsementPolicyFile=./tmp/composer/endorsement-policy.json -A pharmaadmin -C pharmaadmin/admin-pub.pem -A siteadmin -C siteadmin/admin-pub.pem

rm ./pharmaadmin@clinical-trial-network.card
rm ./siteadmin@clinical-trial-network.card

composer card create -p ./tmp/composer/pfizer/clinical-trial-network-pfizer.json -u pharmaadmin -n clinical-trial-network -c pharmaadmin/admin-pub.pem -k pharmaadmin/admin-priv.pem

composer card import -f pharmaadmin@clinical-trial-network.card

composer network ping -c pharmaadmin@clinical-trial-network

composer card create -p ./tmp/composer/manipalhospital/clinical-trial-network-manipalhospital.json -u siteadmin -n clinical-trial-network -c siteadmin/admin-pub.pem -k siteadmin/admin-priv.pem

composer card import -f siteadmin@clinical-trial-network.card

composer network ping -c siteadmin@clinical-trial-network
