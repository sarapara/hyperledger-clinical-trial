echo "Cleaning up old Identity card import ...."
composer card delete -c  PeerAdmin@clinical-trial-network-pfizer
sleep $DELAY
composer card delete -c  PeerAdmin@clinical-trial-network-manipalhospital
sleep $DELAY
composer card delete -c  pharmaadmin@clinical-trial-network
sleep $DELAY
composer card delete -c  siteadmin@clinical-trial-network
sleep $DELAY

echo "Cleaning up files and directories ...."
rm -rf siteadmin
rm -rf pharmaadmin

rm -fr $HOME/.composer
rm -rf ./tmp/composer/pfizer
rm -rf ./tmp/composer/manipalhospital
rm ./clinical-trial-network.json
rm -f *.card
rm ./tmp/composer/ca-orderer.txt
