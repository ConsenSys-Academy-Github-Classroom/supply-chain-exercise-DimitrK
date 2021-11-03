//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../contracts/SupplyChain.sol";

contract ProxyActor {
    address immutable delegate;
    address owner = msg.sender;

    constructor(address delegateSupplyChainAdds) {
        delegate = delegateSupplyChainAdds;
    }

    function shipItem(uint sku) public {
        SupplyChain(delegate).shipItem(sku);
    }

    function receiveItem(uint sku) public {
        SupplyChain(delegate).receiveItem(sku);
    }
}