pragma solidity >=0.4.25 <0.6.0;

import "./DateTime.sol";
import "./SafeMath.sol";
import "./StringExtend.sol";


//create instances for pay-as-you-go services
contract Instanceservice{
    using StringExtend for string;
    address owner;
    mapping(string => address) instances;
    mapping(address =>uint[]) userTimestamps;

    constructor() public {  
        owner = msg.sender;
    }

    function createinstance(address _buyerAddress,uint _productPrice ,string _productDesc, uint8 _firstPayRate,uint8 _totalInstalmentCount) public onlyOwner payable returns(address) {
        address addr = new InstalmentBuyinstance(owner,_buyerAddress,_productPrice,_productDesc,_firstPayRate,_totalInstalmentCount);
        string memory addrStr = addressToAsciiString(_buyerAddress);
        uint timestamp = now;
        string memory timestampStr = uint2str(timestamp);
        string memory result = addrStr.concat(":");
        result = result.concat(timestampStr);
        instances[result] = addr;
        userTimestamps[_buyerAddress].push(timestamp);
        return addr;
    }

    function getinstanceTimestamps(address _addr) public view returns (uint[]) {
        return userTimestamps[_addr];
    }

    function getUserinstances(string _key) public view returns(address) {
        return instances[_key];
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function addressToAsciiString(address x)internal pure returns (string) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            byte b = byte(uint8(uint(x) / (2**(8*(19 - i)))));
            byte hi = byte(uint8(b) / 16);
            byte lo = byte(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);
        }
        return string(s);
    }

    function char(byte b)internal pure returns (byte c) {
        if (b < 10) return byte(uint8(b) + 0x30);
        else return byte(uint8(b) + 0x57);
    }

    function uint2str(uint i) internal pure returns (string){
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0){
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint k = length - 1;
        while (i != 0){
            bstr[k--] = byte(48 + i % 10);
            i /= 10;
        }
        return string(bstr);
    }
}


// Installment is a keyword used for pay-as-you-go service.
contract InstalmentBuyinstance {

    using SafeMath for uint;

    address instance_owner;
    address currentProductOwnerAddr;
    uint8 currentInstalmentNo;
    uint8 totalInstalmentCount;
    uint productPrice;
    string productDesc;
    uint paidMoney;
    uint8 firstPayRate;
    uint createTimeStamp;
    uint lastTimeStamp;
    uint nextTimeStamp;
    uint[] instalmentBills;
    uint[] actualInstalmentBills;

    struct InfoLog{
        address userAddr;
        uint value;
        string action;
        uint timestamp;
    }

    InfoLog[] infoLogs;
    uint totalInfoLogCount;
    uint buyPrice;
    bool isbought = false;
    uint fixedRate = 1;

    constructor (address instanceOwnerAddr,address buyerAddress,uint _productPrice ,string _productDesc, uint8 _firstPayRate,uint8 _totalInstalmentCount) public payable{
        instance_owner = instanceOwnerAddr;
        currentProductOwnerAddr = buyerAddress;
        productPrice = _productPrice *fixedRate;
        productDesc = _productDesc;
        firstPayRate = _firstPayRate;
        totalInstalmentCount = _totalInstalmentCount;
        initInstalMentBills(_productPrice,_firstPayRate,_totalInstalmentCount);
    }

    function initInstalMentBills(uint _productPrice,uint _firstPayRate,uint _totalInstalmentCount) internal {
        uint firstPay = _productPrice.mul(_firstPayRate).div(100);
        uint instalmentPrice = (_productPrice.sub(firstPay)).div(_totalInstalmentCount);
        uint need = instalmentPrice.add(firstPay);
        instalmentBills.push(need);
        for(uint i=1 ; i<_totalInstalmentCount - 1; i++ ) {
            need = need.add(instalmentPrice);
            instalmentBills.push(instalmentPrice);
        }
        instalmentBills.push(_productPrice.sub(need));
    }

    function initTimeStamp() internal {
        createTimeStamp = now;
        lastTimeStamp = createTimeStamp;
    }

    function getNextDays(uint _lastTimeStamp) internal pure returns(uint8) {
        uint16 year = DateTime.getYear(_lastTimeStamp);
        uint8 month = DateTime.getMonth(_lastTimeStamp);
        uint8 daysOfMonth = DateTime.getDaysInMonth(month,year);
        return daysOfMonth;
    }

    function updateTimeStamp(bool isFirst) internal {
        if(isFirst) {
            initTimeStamp();
        }else{
            lastTimeStamp = nextTimeStamp;
        }
        uint8 daysOfMonth = getNextDays(lastTimeStamp);
        nextTimeStamp = lastTimeStamp.add( daysOfMonth * 1 days);
    }

    function payInstalment(address _buyerAddr,uint _value) public payable onlyinstanceOwner instalmentPayValid payValid{
        uint paid = _value ;
        if(paid != instalmentBills[currentInstalmentNo]) {
            revert();
        }else{
            updateTimeStamp( currentInstalmentNo == 0 );
            currentInstalmentNo +=1;
            paidMoney = paidMoney.add(paid);
            actualInstalmentBills.push(paid);
            saveLogInfo(_buyerAddr,paid,"instalmentPay");
        }
    }

    function getNextInstalmentPayInfo() public view returns(uint,uint,uint) {
        if(currentInstalmentNo == 0) {
            return(instalmentBills[currentInstalmentNo],0,now);
        }else{
            if(now > nextTimeStamp) {
                uint diff = now.sub(nextTimeStamp);
                uint d = diff.div(86400);
                if(diff.sub(d.mul(86400)) > 0) {
                    d = d.add(1);
                }
                //0.005 tax rate
                uint tax = instalmentBills[currentInstalmentNo].div(200).mul(d);

                return(instalmentBills[currentInstalmentNo],tax,now);
            }else{
                return(instalmentBills[currentInstalmentNo],0,nextTimeStamp);
            }
        }
    }

    function setbuyPrice(uint _buyPrice) public payable onlyBuyer instalmentPayValid payValid returns(bool){
        buyPrice = _buyPrice.mul(fixedRate);
        isbought = true;
        saveLogInfo(msg.sender,_buyPrice,"setTransferPrice");
        return true;
    }

    function getbuyPrice() public view returns (uint){
        return buyPrice;
    }

    function buyOwnerShip(address _buyerAddr,uint _value) public payable onlyinstanceOwner buyable lockState returns (bool){
        uint value = _value;
        if(value < buyPrice) {
            revert();
            return false;
        }else{
            currentProductOwnerAddr = _buyerAddr;
            buyPrice = 0;
            isbought = false;
            saveLogInfo(currentProductOwnerAddr,value,"buyOwnerShip");
            return true;
        }
    }

    function saveLogInfo(address _addr,uint _value,string _info) internal {
        infoLogs.push(InfoLog(_addr,_value,_info,now));
        totalInfoLogCount = totalInfoLogCount.add(1);
    }

    function getNextTimeStamp() public view returns(uint) {
        return nextTimeStamp;
    }

    function getLastTimeStamp() public view returns(uint) {
        return lastTimeStamp;
    }

    function getInstalMentBills() public view returns (uint[]) {
        return instalmentBills;
    }

    function getActualInstalMentBills() public view returns (uint[]) {
        return actualInstalmentBills;
    }

    function getTotalInfoLogsCount() public view returns(uint) {
        return totalInfoLogCount;
    }

    function getInfoLog(uint pos) public constant returns(address addr, uint value,string action, uint time){
        InfoLog storage infoLog = infoLogs[pos];
        return (infoLog.userAddr, infoLog.value, infoLog.action,infoLog.timestamp);
    }

    function getCurrentInstalmentNo() public view returns (uint8) {
        return currentInstalmentNo;
    }

    function getTotalInstalmentCount() public view returns (uint8) {
        return totalInstalmentCount;
    }

    function getProductPrice() public view returns (uint) {
        return productPrice;
    }

    function getProductDesc() public view returns (string) {
        return productDesc;
    }

    function getPaidMoney() public view returns (uint) {
        return paidMoney;
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getCurrentProductOwnerAddr() public view returns(address) {
        return currentProductOwnerAddr;
    }

    modifier onlyinstanceOwner {
        require(msg.sender == instance_owner);
        _;
    }

    modifier onlyBuyer {
        require(msg.sender == currentProductOwnerAddr);
        _;
    }

    modifier instalmentPayValid {
        require(currentInstalmentNo < totalInstalmentCount);
        _;
    }

    modifier payValid{
        require(paidMoney < productPrice);
        _;
    }

    modifier buyable {
        require(isbought);
        _;
    }

    modifier lockState {
        require(now < nextTimeStamp);
        _;
    }
}
