ipfs daemon &
IPFS_PID=$!
echo "Running IPFS daemon PID: $IPFS_PID"
sleep 5s
node index.js
