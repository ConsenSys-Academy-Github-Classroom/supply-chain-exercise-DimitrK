// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SupplyChain {
    // <owner>
    address immutable public owner = msg.sender;

    // <skuCount>
    uint public skuCount;

    // <items mapping>
    mapping(uint => Item) public items;

    // <enum State: ForSale, Sold, Shipped, Received>
    enum State {
        ForSale,
        Sold,
        Shipped,
        Received
    }

    // <struct Item: name, sku, price, state, seller, and buyer>

    struct Item {
        string name;
        uint sku;
        uint price;
        State state;
        address payable seller;
        address payable buyer;
    }

    /*
     * Events
     */

    // <LogForSale event: sku arg>
    event LogForSale(uint indexed sku);

    // <LogSold event: sku arg>
    event LogSold(uint indexed sku);
    event LogSellFailure(uint indexed sku);
    event LogSelling(uint indexed sku);

    // <LogShipped event: sku arg>
    event LogShipped(uint indexed sku);

    // <LogReceived event: sku arg>
    event LogReceived(uint indexed sku);

    /*
     * Modifiers
     */

    // Create a modifer, `isOwner` that checks if the msg.sender is the owner of the contract

    // <modifier: isOwner

    modifier isOwner(address _address) {
        require(msg.sender == owner, "only owner is allowed to do that");
        _;
    }

    modifier verifyCaller(address _address) {
        require(
            msg.sender == _address,
            "caller address does not match the given address"
        );
        _;
    }

    modifier paidEnough(uint _price) {
        require(msg.value >= _price, "insufficient funds");
        _;
    }

    modifier checkValue(uint _sku) {
        //refund them after pay for item (why it is before, _ checks for logic before func)
        _;
        uint _price = items[_sku].price;
        uint amountToRefund = msg.value - _price;
        items[_sku].buyer.transfer(amountToRefund);
    }

    // For each of the following modifiers, use what you learned about modifiers
    // to give them functionality. For example, the forSale modifier should
    // require that the item with the given sku has the state ForSale. Note that
    // the uninitialized Item.State is 0, which is also the index of the ForSale
    // value, so checking that Item.State == ForSale is not sufficient to check
    // that an Item is for sale. Hint: What item properties will be non-zero when
    // an Item has been added?

    // modifier forSale
    modifier forSale(uint _sku) {
        if (items[_sku].state != State.ForSale || items[_sku].price <= 0) {
          emit LogSellFailure(_sku);
        }
        require(items[_sku].state == State.ForSale && items[_sku].price > 0);
        _;
    }
    // modifier sold(uint _sku)
    modifier sold(uint _sku) {
        _;
        require(items[_sku].state == State.ForSale);
        items[_sku].state = State.Sold;

        emit LogSold(_sku);
    }
    // modifier shipped(uint _sku)
    modifier shipped(uint _sku) {
        require(items[_sku].state == State.Sold);
        _;
    }
    // modifier received(uint _sku)
    modifier received(uint _sku) {
        require(items[_sku].state == State.Shipped);
        _;
    }

    function addItem(string memory _name, uint _price)
        public
        returns (bool)
    {
        require(_price > 0, "invalid selling price given");
        require(bytes(_name).length > 0, "invalid item name given");

        uint _sku = skuCount;
        items[_sku] = Item({
            name: _name,
            sku: skuCount,
            price: _price,
            state: State.ForSale,
            seller: payable(msg.sender),
            buyer: payable(address(0))
        });

        skuCount++;

        emit LogForSale(_sku);
        return true;
    }

    // Implement this buyItem function.
    // 1. it should be payable in order to receive refunds
    // 2. this should transfer money to the seller,
    // 3. set the buyer as the person who called this transaction,
    // 4. set the state to Sold.
    // 5. this function should use 3 modifiers to check
    //    - if the item is for sale,
    //    - if the buyer paid enough,
    //    - check the value after the function is called to make
    //      sure the buyer is refunded any excess ether sent.
    // 6. call the event associated with this function!
    function buyItem(uint sku)
        public
        payable
        forSale(sku)
        paidEnough(sku)
        checkValue(sku)
        sold(sku)
    {
        Item storage item = items[sku];
        item.seller.transfer(item.price);
        item.buyer = payable(msg.sender);
    }

    // 1. Add modifiers to check:
    //    - the item is sold already
    //    - the person calling this function is the seller.
    // 2. Change the state of the item to shipped.
    // 3. call the event associated with this function!
    function shipItem(uint sku)
        public
        verifyCaller(items[sku].seller)
        shipped(sku)
    {
        items[sku].state = State.Shipped;

        emit LogShipped(sku);
    }

    // 1. Add modifiers to check
    //    - the item is shipped already
    //    - the person calling this function is the buyer.
    // 2. Change the state of the item to received.
    // 3. Call the event associated with this function!
    function receiveItem(uint sku)
        public
        verifyCaller(items[sku].buyer)
        received(sku)
    {
        items[sku].state = State.Received;

        emit LogReceived(sku);
    }

    // Uncomment the following code block. it is needed to run tests
    function fetchItem(uint _sku)
        public
        view
        returns (
            string memory name,
            uint sku,
            uint price,
            uint state,
            address seller,
            address buyer
        )
    {
        name = items[_sku].name;
        sku = items[_sku].sku;
        price = items[_sku].price;
        state = uint(items[_sku].state);
        seller = items[_sku].seller;
        buyer = items[_sku].buyer;
    }
}
