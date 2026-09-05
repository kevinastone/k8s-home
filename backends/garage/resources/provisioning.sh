## Create the layout

#TODO: Get NodeIDs programmatically
./garage.sh layout assign fa -c 100GB -z g0
./garage.sh layout assign 65 -c 100GB -z g1
./garage.sh layout assign 24 -c 100GB -z g2

./garage.sh layout show apply --version 1

## Create Users
# ./garage.sh key create postgres
# ./garage.sh key import --yes postgres <secret>

## Create Buckets
./garage.sh bucket create postgres

## Permissions
./garage.sh bucket allow --read --write postgres --key postgres
