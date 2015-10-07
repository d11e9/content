contract Archive {
    
    struct Content {
        bool exists;
        address OP;
        bytes32[] archives;
    }
    
    uint totalOC;
    mapping(uint => bytes32) public OC;
    mapping(bytes32 => Content) public contents;
    
    function archive( bytes32 rootContentHash, bytes32 archive, address OP ) {
        address archiver = msg.sender;
        if (contents[rootContentHash].exists && archive != bytes32(0)) {
            // append to archive
            contents[rootContentHash].archives.length++;
            contents[rootContentHash].archives[contents[rootContentHash].archives.length] = archive;
        } else if (!contents[rootContentHash].exists) {
            // first archival
            bytes32[] memory tmp;
            contents[rootContentHash] = Content( true, OP, tmp);
            OC[totalOC++] = rootContentHash;
        }
    }
}
