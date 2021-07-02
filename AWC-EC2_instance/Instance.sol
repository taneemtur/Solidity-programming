pragma solidity >=0.4.25 <0.6.0;

contract Instance {
	     
    int public id;
    string public name;
    address public owner;
    int256 public price;

    enum StateType { Owner, Buyer}
    StateType public state;
        
    constructor (int InstanceId, string memory InstanceName) public 
    {
        id = InstanceId;
        name  = InstanceName;
        state = StateType.Owner;
        owner = msg.sender;
    }
    
    function setOwner(address InstanceOwner) public {
        owner = InstanceOwner;
    }
    
    function setState(StateType InstanceState) public {
        state = InstanceState;
    }
}   