ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8082
ipfs daemon &
IPFS_PID=$!
echo "Running IPFS daemon PID: $IPFS_PID"
sleep 5s
node index.js
