// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";
import "./helpers/ProxyActor.sol";

contract TestSupplyChain {
    SupplyChain chain;
    uint256 public initialBalance = 1 ether;
    uint constant RECEIVED = 3;
    uint constant SHIPPED = 2;
    uint constant SOLD = 1;
    uint constant FORSALE = 0;
    fallback() external payable {}

    receive() external payable {}

    function _callBuyItem(uint256 sku, uint256 amount)
        private
        returns (bool result, bytes memory data)
    {
        (result, data) = address(chain).call{value: amount}(
            abi.encodeWithSignature("buyItem(uint256)", sku)
        );
    }

    function _fetchItemState(uint sku) private view returns (uint state) {
        (, , , state, ,) = chain.fetchItem(sku);
    }

    function beforeEach() public {
        chain = new SupplyChain();
    }

    function testInitialisedOwnerUponCreation() public {
        Assert.equal(
            chain.owner(),
            address(this),
            "owner should be same as the deployer contract"
        );
    }

    function testInitiaisedOwnerOfDeployedContract() public {
        SupplyChain _chain = SupplyChain(DeployedAddresses.SupplyChain());
        Assert.isNotZero(_chain.owner(), "owner should be set");
        Assert.equal(
            _chain.owner(),
            msg.sender,
            "owner should be same as the deployer"
        );
    }

    // Test for failing conditions in this contracts:
    // https://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests

    // buyItem

    // test for failure if user does not send enough funds
    function testFailNotEnoughFunds() public {
        chain.addItem("expensive", 2 ether);
        (bool result, ) = _callBuyItem(0, 2 ether);

        Assert.isFalse(
            result,
            "should not allow purchase without enough funds"
        );
    }

    function testBuyItem() public {
        chain.addItem("item", 5000 wei);
        (bool boughtResult, ) = _callBuyItem(0, 5000 wei);
        Assert.isTrue(boughtResult, "should purchase an item");
        Assert.equal(_fetchItemState(0), SOLD, 'should set item state to sold');
    }

    function testFailBuyNonExistingItem() public {
        // Never added an item
        (bool boughtResult, ) = _callBuyItem(0, 5000 wei);
        Assert.isFalse(boughtResult, "should not be able to purchase a non-existing item");
    }

    // // test for purchasing an item that is not for Sale
    function testFailBuyNotForSale() public {
        chain.addItem("item", 5000 wei);
         _callBuyItem(0, 5000 wei);

        (bool result, ) = _callBuyItem(0, 5000 wei);
        Assert.isFalse(result, "should not purchase an item already sold");
    }
    // shipItem

    // test for calls that are made by not the seller
    function testOnlySelerShipsSoldItem() public {
        chain.addItem("item", 5000 wei);
        _callBuyItem(0, 5000 wei);

        ProxyActor actor = new ProxyActor(address(chain));
        (bool actorResult, ) = address(actor).call(abi.encodeWithSignature("shipItem(uint256)", 0));
        Assert.isFalse(actorResult, "should fail shipping from other than the seller");
        Assert.notEqual(_fetchItemState(0), SHIPPED, "should not have state shipped from other than the seller");

        (bool chainResult, ) = address(chain).call(abi.encodeWithSignature("shipItem(uint256)", 0));
        Assert.isTrue(chainResult, "should execute ship from the seller");
        Assert.equal(_fetchItemState(0), SHIPPED, "should have status changed to shipped from the seller");
    }

    // test for trying to ship an item that is not marked Sold
    function testFailShippingItemBeforeSold() public {
        chain.addItem("item", 5000 wei);

        (bool chainResult, ) = address(chain).call(abi.encodeWithSignature("shipItem(uint256)", 0));

        Assert.isFalse(chainResult, "should fail executing ship item before being sold");
        Assert.equal(_fetchItemState(0), FORSALE, "should not change status to shipped before being sold");
    }

    // receiveItem

    // test calling the function from an address that is not the buyer
    function testOnlyBuyerReceivesShippedItem() public {
        chain.addItem("item", 5000 wei);
        _callBuyItem(0, 5000 wei);
        chain.shipItem(0);

        ProxyActor actor = new ProxyActor(address(chain));
        (bool actorResult, ) = address(actor).call(abi.encodeWithSignature("receiveItem(uint256)", 0));
        Assert.isFalse(actorResult, "should fail executing receive from other than the seller");
        Assert.notEqual(_fetchItemState(0), RECEIVED, "should not have state received from other than the seller");

        (bool chainResult, ) = address(chain).call(abi.encodeWithSignature("receiveItem(uint256)", 0));
        Assert.isTrue(chainResult, "should execute receive from the seller");
        Assert.equal(_fetchItemState(0), RECEIVED, "should have status changed to received from the seller");
    }

    // test calling the function on an item not marked Shipped
    function testFailReceiveNonShippedItem() public {
        chain.addItem("item", 5000 wei);
        _callBuyItem(0, 5000 wei);

        (bool chainResult, ) = address(chain).call(abi.encodeWithSignature("receiveItem(uint256)", 0));
        Assert.equal(_fetchItemState(0), SOLD, "should keep status sold instead of received");
        Assert.isFalse(chainResult, "should fail to execute receive");
    }
}
