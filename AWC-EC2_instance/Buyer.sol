pragma solidity >=0.4.25 <0.6.0;

import "./Instance.sol";
import "./InstanceTracker.sol";

contract Buyer
{
    string public name;
    address public buyer_address;

    constructor(string memory buyerName, address buyerAddress) public
    {
        name = buyerName;
        buyer_address = buyerAddress;
    }

}
