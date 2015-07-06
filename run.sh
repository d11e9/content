ipfs config Addresses.Gateway /ip4/127.0.0.1/tcp/8082
ipfs daemon &
IPFS_PID=$!
echo "Running IPFS daemon PID: $IPFS_PID"
sleep 5s
node index.js
