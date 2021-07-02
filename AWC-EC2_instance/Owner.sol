pragma solidity >=0.4.25 <0.6.0;


contract Owner
{
    string public name;
    address public Owner_address;

    constructor ( string memory OwnerName) public {
        name = OwnerName;
        Owner_address = msg.sender;
    }
}