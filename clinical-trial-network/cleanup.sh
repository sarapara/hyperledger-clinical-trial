NETWORK_NAME="$1"
echo "Cleaning up old Identity card import ...."
composer card delete -c  PeerAdmin@$NETWORK_NAME-pfizer
sleep $DELAY
composer card delete -c  PeerAdmin@$NETWORK_NAME-manipalhospital
sleep $DELAY
composer card delete -c  pharmaadmin@$NETWORK_NAME
sleep $DELAY
composer card delete -c  siteadmin@$NETWORK_NAME
sleep $DELAY

echo "Cleaning up files and directories ...."
rm -rf siteadmin
rm -rf pharmaadmin

rm -fr $HOME/.composer
rm -rf ./tmp
rm ./$NETWORK_NAME.json
rm -f *.card
