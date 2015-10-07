
import "owned";

contract Archive is owned {
    
    struct Content {
        bool exists;
        address OP;
        bytes32[] archives;
    }
    
    uint public price;
    mapping(bytes32 => Content) public contents;
    
    event Post(bytes32 rootHash, bytes32 contentHash);
    
    modifier costs { if (msg.value >= price) _ }
    
    function archive( bytes32 rootContentHash, bytes32 archive, address OP, bool tip ) costs {
        address archiver = msg.sender;
        if (contents[rootContentHash].exists && archive != bytes32(0)) {
            
            // append to archive
            contents[rootContentHash].archives.length++;
            contents[rootContentHash].archives[contents[rootContentHash].archives.length] = archive;
            Post( rootContentHash, archive);
            handleTip( tip, OP );
            
        } else if (!contents[rootContentHash].exists) {
            
            // first archival
            bytes32[] memory tmp;
            contents[rootContentHash] = Content( true, OP, tmp);
            Post( rootContentHash, bytes32(0));
            handleTip( tip, OP );
        }
    }
    
    function handleTip (bool tip, address OP) internal {
        if (tip && OP != address(0)) {
            OP.send( price );
        } else {
            owner.send( price );
        }
    }
    
    function changePrice(uint _price) onlyowner {
        price = _price;
    }
}
