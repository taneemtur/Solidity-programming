// SPDX-License-Identifier: MIT

pragma solidity ^0.5.4;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

library Objects {
    struct Investment {
        uint256 boardId;
        uint256 investmentDate;
        uint256 investment;
        uint256 lastWithdrawalDate;
        uint256 currentDividends;
        bool isExpired;
    }

    struct board {
        uint256 cyclecount;
        uint256 term; 
        uint256 maxcyclecount;
    }

    struct parent {
        address addr;
        uint256 referrerEarnings;
        uint256 availableReferrerEarnings;
        uint256 referrer;
        uint256 boardCount;
        mapping(uint256 => Investment) boards;
        uint256 level1RefCount;
        uint256 level2RefCount;
    }
}

contract Ownable {
    address public owner;

    event onOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  
    constructor() public {
        owner = msg.sender;
    }
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0));
        emit onOwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}

contract OctaTron is Ownable {
    using SafeMath for uint256;
    uint256 private constant FIRST_CYCLE = 1 days;
    uint256 private constant DEVELOPER_ENTRY_RATE = 20; //per thousand
    uint256 private constant ADMIN_ENTRY_RATE = 90;
    uint256 private constant REFERENCE_RATE = 60;
    uint256 private constant DEVELOPER_EXIT_RATE = 10; //per thousand
    uint256 private constant ADMIN_EXIT_RATE = 30;


    uint256 public constant REFERENCE_LEVEL1_RATE = 50;
    uint256 public constant REFERENCE_LEVEL2_RATE = 10;
    uint256 public constant MINIMUM = 250; //minimum investment needed
    uint256 public constant REFERRER_CODE = 6666; //default

    uint256 public latestReferrerCode;
    uint256 private totalInvestments_;

    address payable private developerAccount_;
    address payable private RefereesAccount_;
    address payable private referenceAccount_;

    mapping(address => uint256) public address2UID;
    mapping(uint256 => Objects.parent) public uid2parent;
    Objects.board[] private investmentboards_;

    event onInvest(address parent, uint256 amount);
    event onGrant(address grantor, address beneficiary, uint256 amount);
    event onWithdraw(address parent, uint256 amount);
    
    
     constructor() public {
        developerAccount_ = msg.sender;
        RefereesAccount_ = msg.sender;
        referenceAccount_ = msg.sender;
        _init();
    }

    function() external payable {
        if (msg.value == 0) {
            withdraw();
        } else {
            invest(0, 0); //default to buy plan 0, no referrer
        }
    }
    
    function checkIn() public {
    }

    function setRefereesAccount(address payable _newRefereesAccount) public onlyOwner {
        require(_newRefereesAccount != address(0));
        RefereesAccount_ = _newRefereesAccount;
    }

    function getRefereesAccount() public view onlyOwner returns (address) {
        return RefereesAccount_;
    }


    function getDeveloperAccount() public view onlyOwner returns (address) {
        return developerAccount_;
    }

    function setReferenceAccount(address payable _newReferenceAccount) public onlyOwner {
        require(_newReferenceAccount != address(0));
        referenceAccount_ = _newReferenceAccount;
    }

    function getReferenceAccount() public view onlyOwner returns (address) {
        return referenceAccount_;
    }

    function _init() private {
        latestReferrerCode = REFERRER_CODE;
        address2UID[msg.sender] = latestReferrerCode;
        uid2parent[latestReferrerCode].addr = msg.sender;
        uid2parent[latestReferrerCode].referrer = 0;
        uid2parent[latestReferrerCode].boardCount = 0;
        investmentboards_.push(Objects.board(27,79*60*60*24,37)); 
        investmentboards_.push(Objects.board(37, 48*60*60*24,47)); 
        investmentboards_.push(Objects.board(47, 28*60*60*24,57));
        investmentboards_.push(Objects.board(57, 20*60*60*24,67)); 
    }

    function getCurrentboards() public view returns (uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory) {
        uint256[] memory ids = new uint256[](investmentboards_.length);
        uint256[] memory interests = new uint256[](investmentboards_.length);
        uint256[] memory terms = new uint256[](investmentboards_.length);
        uint256[] memory maxInterests = new uint256[](investmentboards_.length);
        for (uint256 i = 0; i < investmentboards_.length; i++) {
            Objects.board storage board = investmentboards_[i];
            ids[i] = i;
            interests[i] = board.cyclecount;
            maxInterests[i] = board.maxcyclecount;
            terms[i] = board.term;
        }
        return
        (
        ids,
        interests,
        maxInterests,
        terms
        );
    }

    function getTotalInvestments() public view returns (uint256){
        return totalInvestments_;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUIDByAddress(address _addr) public view returns (uint256) {
        return address2UID[_addr];
    }

    function getparentInfoByUID(uint256 _uid) public view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256[] memory, uint256[] memory) {
        if (msg.sender != owner) {
            require(address2UID[msg.sender] == _uid, "only owner or self can check the parent info.");
        }
        Objects.parent storage parent = uid2parent[_uid];
        uint256[] memory newDividends = new uint256[](parent.boardCount);
        uint256[] memory currentDividends = new  uint256[](parent.boardCount);
        for (uint256 i = 0; i < parent.boardCount; i++) {
            require(parent.boards[i].investmentDate != 0, "wrong investment date");
            currentDividends[i] = parent.boards[i].currentDividends;
            if (parent.boards[i].isExpired) {
                newDividends[i] = 0;
            } else {
                if (investmentboards_[parent.boards[i].boardId].term > 0) {
                    if (block.timestamp >= parent.boards[i].investmentDate.add(investmentboards_[parent.boards[i].boardId].term)) {
                        newDividends[i] = _calculateDividends(parent.boards[i].investment, investmentboards_[parent.boards[i].boardId].cyclecount, parent.boards[i].investmentDate.add(investmentboards_[parent.boards[i].boardId].term), parent.boards[i].lastWithdrawalDate, investmentboards_[parent.boards[i].boardId].maxcyclecount);
                    } else {
                        newDividends[i] = _calculateDividends(parent.boards[i].investment, investmentboards_[parent.boards[i].boardId].cyclecount, block.timestamp, parent.boards[i].lastWithdrawalDate, investmentboards_[parent.boards[i].boardId].maxcyclecount);
                    }
                } else {
                    newDividends[i] = _calculateDividends(parent.boards[i].investment, investmentboards_[parent.boards[i].boardId].cyclecount, block.timestamp, parent.boards[i].lastWithdrawalDate, investmentboards_[parent.boards[i].boardId].maxcyclecount);
                }
            }
        }
        return
        (
        parent.referrerEarnings,
        parent.availableReferrerEarnings,
        parent.referrer,
        parent.level1RefCount,
        parent.level2RefCount,
        parent.boardCount,
        currentDividends,
        newDividends
        );
    }

    function getInvestmentboardByUID(uint256 _uid) public view returns (uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory,uint256[] memory, bool[] memory) {
        if (msg.sender != owner) {
            require(address2UID[msg.sender] == _uid, "only owner or self can check the investment board info.");
        }
        Objects.parent storage parent = uid2parent[_uid];
        uint256[] memory boardIds = new  uint256[](parent.boardCount);
        uint256[] memory investmentDates = new  uint256[](parent.boardCount);
        uint256[] memory investments = new  uint256[](parent.boardCount);
        uint256[] memory currentDividends = new  uint256[](parent.boardCount);
        bool[] memory isExpireds = new  bool[](parent.boardCount);
        uint256[] memory newDividends = new uint256[](parent.boardCount);
        uint256[] memory interests = new uint256[](parent.boardCount);

        for (uint256 i = 0; i < parent.boardCount; i++) {
            require(parent.boards[i].investmentDate!=0,"wrong investment date");
            boardIds[i] = parent.boards[i].boardId;
            currentDividends[i] = parent.boards[i].currentDividends;
            investmentDates[i] = parent.boards[i].investmentDate;
            investments[i] = parent.boards[i].investment;
            if (parent.boards[i].isExpired) {
                isExpireds[i] = true;
                newDividends[i] = 0;
                interests[i] = investmentboards_[parent.boards[i].boardId].cyclecount;
            } else {
                isExpireds[i] = false;
                if (investmentboards_[parent.boards[i].boardId].term > 0) {
                    if (block.timestamp >= parent.boards[i].investmentDate.add(investmentboards_[parent.boards[i].boardId].term)) {
                        newDividends[i] = _calculateDividends(parent.boards[i].investment, investmentboards_[parent.boards[i].boardId].cyclecount, parent.boards[i].investmentDate.add(investmentboards_[parent.boards[i].boardId].term), parent.boards[i].lastWithdrawalDate, investmentboards_[parent.boards[i].boardId].maxcyclecount);
                        isExpireds[i] = true;
                        interests[i] = investmentboards_[parent.boards[i].boardId].cyclecount;
                    }else{
                        newDividends[i] = _calculateDividends(parent.boards[i].investment, investmentboards_[parent.boards[i].boardId].cyclecount, block.timestamp, parent.boards[i].lastWithdrawalDate, investmentboards_[parent.boards[i].boardId].maxcyclecount);
                        uint256 numberOfDays =  (block.timestamp - parent.boards[i].lastWithdrawalDate) / FIRST_CYCLE ;
                        interests[i] = (numberOfDays < 10) ? investmentboards_[parent.boards[i].boardId].cyclecount + numberOfDays : investmentboards_[parent.boards[i].boardId].maxcyclecount;
                    }
                } else {
                    newDividends[i] = _calculateDividends(parent.boards[i].investment, investmentboards_[parent.boards[i].boardId].cyclecount, block.timestamp, parent.boards[i].lastWithdrawalDate, investmentboards_[parent.boards[i].boardId].maxcyclecount);
                    uint256 numberOfDays =  (block.timestamp - parent.boards[i].lastWithdrawalDate) / FIRST_CYCLE ;
                    interests[i] = (numberOfDays < 10) ? investmentboards_[parent.boards[i].boardId].cyclecount + numberOfDays : investmentboards_[parent.boards[i].boardId].maxcyclecount;
                }
            }
        }

        return
        (
        boardIds,
        investmentDates,
        investments,
        currentDividends,
        newDividends,
        interests,
        isExpireds
        );
    }

    function _addparent(address _addr, uint256 _referrerCode) private returns (uint256) {
        if (_referrerCode >= REFERRER_CODE) {
            if (uid2parent[_referrerCode].addr == address(0)) {
                _referrerCode = 0;
            }
        } else {
            _referrerCode = 0;
        }
        address addr = _addr;
        latestReferrerCode = latestReferrerCode.add(1);
        address2UID[addr] = latestReferrerCode;
        uid2parent[latestReferrerCode].addr = addr;
        uid2parent[latestReferrerCode].referrer = _referrerCode;
        uid2parent[latestReferrerCode].boardCount = 0;
        if (_referrerCode >= REFERRER_CODE) {
            uint256 _ref1 = _referrerCode;
            uint256 _ref2 = uid2parent[_ref1].referrer;
            uid2parent[_ref1].level1RefCount = uid2parent[_ref1].level1RefCount.add(1);
            if (_ref2 >= REFERRER_CODE) {
                uid2parent[_ref2].level2RefCount = uid2parent[_ref2].level2RefCount.add(1);
            }
        }
        return (latestReferrerCode);
    }

    function _invest(address _addr, uint256 _boardId, uint256 _referrerCode, uint256 _amount) private returns (bool) {
        require(_boardId >= 0 && _boardId < investmentboards_.length, "Wrong investment board id");
        require(_amount >= MINIMUM, "Less than the minimum amount of deposit requirement");
        uint256 uid = address2UID[_addr];
        if (uid == 0) {
            uid = _addparent(_addr, _referrerCode);
        } else {
        }
        uint256 boardCount = uid2parent[uid].boardCount;
        Objects.parent storage parent = uid2parent[uid];
        parent.boards[boardCount].boardId = _boardId;
        parent.boards[boardCount].investmentDate = block.timestamp;
        parent.boards[boardCount].lastWithdrawalDate = block.timestamp;
        parent.boards[boardCount].investment = _amount;
        parent.boards[boardCount].currentDividends = 0;
        parent.boards[boardCount].isExpired = false;

        parent.boardCount = parent.boardCount.add(1);

        _calculateReferrerReward(_amount, parent.referrer);

        totalInvestments_ = totalInvestments_.add(_amount);

        uint256 developerPercentage = (_amount.mul(DEVELOPER_ENTRY_RATE)).div(1000);
        developerAccount_.transfer(developerPercentage);
        uint256 RefereesPercentage = (_amount.mul(ADMIN_ENTRY_RATE)).div(1000);
        RefereesAccount_.transfer(RefereesPercentage);
        return true;
    }

    function grant(address addr, uint256 _boardId) public payable {
        uint256 grantorUid = address2UID[msg.sender];
        bool isAutoAddReferrer = true;
        uint256 referrerCode = 0;

        if (grantorUid != 0 && isAutoAddReferrer) {
            referrerCode = grantorUid;
        }

        if (_invest(addr,_boardId,referrerCode,msg.value)) {
            emit onGrant(msg.sender, addr, msg.value);
        }
    }

    function invest(uint256 _referrerCode, uint256 _boardId) public payable {
        if (_invest(msg.sender, _boardId, _referrerCode, msg.value)) {
            emit onInvest(msg.sender, msg.value);
        }
    }

    function withdraw() public payable {
        require(msg.value == 0, "withdrawal doesn't allow to transfer trx simultaneously");
        uint256 uid = address2UID[msg.sender];
        require(uid != 0, "Can not withdraw because no any investments");
        uint256 withdrawalAmount = 0;
        for (uint256 i = 0; i < uid2parent[uid].boardCount; i++) {
            if (uid2parent[uid].boards[i].isExpired) {
                continue;
            }

            Objects.board storage board = investmentboards_[uid2parent[uid].boards[i].boardId];

            bool isExpired = false;
            uint256 withdrawalDate = block.timestamp;
            if (board.term > 0) {
                uint256 endTime = uid2parent[uid].boards[i].investmentDate.add(board.term);
                if (withdrawalDate >= endTime) {
                    withdrawalDate = endTime;
                    isExpired = true;
                }
            }

            uint256 amount = _calculateDividends(uid2parent[uid].boards[i].investment , board.cyclecount , withdrawalDate , uid2parent[uid].boards[i].lastWithdrawalDate , board.maxcyclecount);

            withdrawalAmount += amount;
            

            uid2parent[uid].boards[i].lastWithdrawalDate = withdrawalDate;
            uid2parent[uid].boards[i].isExpired = isExpired;
            uid2parent[uid].boards[i].currentDividends += amount;
        }
        
        
        uint256 developerPercentage = (withdrawalAmount.mul(DEVELOPER_EXIT_RATE)).div(1000);
        developerAccount_.transfer(developerPercentage);
        uint256 RefereesPercentage = (withdrawalAmount.mul(ADMIN_EXIT_RATE)).div(1000);
        RefereesAccount_.transfer(RefereesPercentage);

        msg.sender.transfer(withdrawalAmount.sub(developerPercentage.add(RefereesPercentage)));

        if (uid2parent[uid].availableReferrerEarnings>0) {
            msg.sender.transfer(uid2parent[uid].availableReferrerEarnings);
            uid2parent[uid].referrerEarnings = uid2parent[uid].availableReferrerEarnings.add(uid2parent[uid].referrerEarnings);
            uid2parent[uid].availableReferrerEarnings = 0;
        }

        emit onWithdraw(msg.sender, withdrawalAmount);
    }

    function _calculateDividends(uint256 _amount, uint256 _cyclecountRate, uint256 _now, uint256 _start , uint256 _maxcyclecount) private pure returns (uint256) {

        uint256 numberOfDays =  (_now - _start) / FIRST_CYCLE ;
        uint256 result = 0;
        uint256 index = 0;
        if(numberOfDays > 0){
          uint256 secondsLeft = (_now - _start);
           for (index; index < numberOfDays; index++) {
               if(_cyclecountRate + index <= _maxcyclecount ){
                   secondsLeft -= FIRST_CYCLE;
                     result += (_amount * (_cyclecountRate + index) / 1000 * FIRST_CYCLE) / (60*60*24);
               }
               else{
                 break;
               }
            }

            result += (_amount * (_cyclecountRate + index) / 1000 * secondsLeft) / (60*60*24);

            return result;

        }else{
            return (_amount * _cyclecountRate / 1000 * (_now - _start)) / (60*60*24);
        }

    }

    function _calculateReferrerReward(uint256 _investment, uint256 _referrerCode) private {

        uint256 _allReferrerAmount = (_investment.mul(REFERENCE_RATE)).div(1000);
        if (_referrerCode != 0) {
            uint256 _ref1 = _referrerCode;
            uint256 _ref2 = uid2parent[_ref1].referrer;
            uint256 _refAmount = 0;

            if (_ref1 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL1_RATE)).div(1000);
                _allReferrerAmount = _allReferrerAmount.sub(_refAmount);
                uid2parent[_ref1].availableReferrerEarnings = _refAmount.add(uid2parent[_ref1].availableReferrerEarnings);
                
            }

            if (_ref2 != 0) {
                _refAmount = (_investment.mul(REFERENCE_LEVEL2_RATE)).div(1000);
                _allReferrerAmount = _allReferrerAmount.sub(_refAmount);
                uid2parent[_ref2].availableReferrerEarnings = _refAmount.add(uid2parent[_ref2].availableReferrerEarnings);
            }

        }

        if (_allReferrerAmount > 0) {
            referenceAccount_.transfer(_allReferrerAmount);
        }
    }

}