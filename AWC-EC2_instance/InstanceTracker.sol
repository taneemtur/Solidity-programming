pragma solidity >=0.4.25 <0.6.0;

import "./Instance.sol";
import "./Owner.sol";
import "./Buyer.sol";

contract InstanceTracker
{
    mapping (address => Owner) public owners;
    mapping (address => Buyer) public buyers;
    mapping (int => Instance) public instances;
    int public InstanceId ;

    event InstanceCreate(address account, int InstanceID, string Owner);
    event InstanceTransfer(address from, address to, int InstanceID);
    
    function createOwner(string memory ownerName, address ownerAddress) public
    {
        Owner owner = new Owner(ownerName);
        owners[ownerAddress] = owner;
    }
    
    function createBuyer(string memory buyerName, address buyerAddress) public
    {
        Buyer buyer = new Buyer(buyerName, buyerAddress);
        buyers[buyerAddress] = buyer;
    }
    
    function createInstance(string memory instanceName) public returns (int)
    {
       if (msg.sender != owners[msg.sender].Owner_address())
            revert();
        InstanceId = InstanceId + 1;
        Instance instance =  new Instance(InstanceId, instanceName);
        instances[InstanceId] = instance;
        
        emit InstanceCreate (msg.sender, InstanceId, owners[msg.sender].name());
        return InstanceId;
    }

 
    function getCurrentOwner(int InstanceID) public view returns(address) {
        Instance instance = instances[InstanceID];
        return instance.owner();
    }
    function getOwnerAdress(address adr) public view returns(address) {
             Owner owner = owners[adr];
             return owner.Owner_address();
    }
    function getCurrentState(int InstanceID) public view returns(Instance.StateType) {
        Instance instance = instances[InstanceID];
        return instance.state();
    }

    function transferInstance(address to, int InstanceID) public 
    {
        Instance instance = instances[InstanceID];
        if(int(instance.state()) == 0 && to == buyers[to].buyer_address())
        {
            instance.setOwner(to);
            instance.setState(Instance.StateType.Buyer);
        }
       
        emit InstanceTransfer (msg.sender, to, InstanceID);
    
      
	}
}



