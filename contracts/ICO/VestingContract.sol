//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;

import "../interfaces/IERC20.sol";

contract VestingContract {

    uint8 private nextSubtract;
    uint8 private nextScheduleId;
    bool public initialized;
    bool private configured;

    address[] private beneficiaries;
    uint[] private scheduleList;

    mapping(uint8 => uint) private schedules;
    mapping(address => mapping(address => uint)) private balances;
    mapping(address => uint) private percentages;
    
    event NewVesting(address newVestingContract, uint indexed timeCreated);
    event Distributed(address token, address executor, uint round);
    event Withdrawn(address token, address beneficiary, uint amount);
    event EtherWithdrawn(address _addr, uint _value);
    
    modifier whenNotInitialized() {
        require(initialized == false, "Vesting has already been initialized");
        _;
    }
    
    modifier whenInitialized() {
        require(initialized == true, "Vesting has not been initialized");
        _;
    }
    
    modifier onlyBeneficiary() {
        bool isApproved = false;
        for(uint i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i] == msg.sender) {
                isApproved = true;
            }
        }
        require(isApproved == true, "Only a beneficiary can do this");
        _;
    }
    
    function addParameters(address[] calldata _beneficiary, uint[] calldata _percentages, uint[] calldata _schedules) external whenNotInitialized {
        require(_beneficiary.length == _percentages.length, 'Beneficiary and percentage arrays must have the same length');
        require(configured == false, 'Parameters have already been added');
        uint totalPercentages;
        for(uint i = 0; i < _beneficiary.length; i++) {
            beneficiaries.push(_beneficiary[i]);
            percentages[_beneficiary[i]] = _percentages[i];
            totalPercentages = totalPercentages + _percentages[i];
        }
        require(totalPercentages == 100, 'Percentages must sum up to 100');
        for(uint8 i = 0; i < _schedules.length; i++) {
            scheduleList.push(_schedules[i]);
        }
        configured = true;
    }
    
    function startVesting() external whenNotInitialized onlyBeneficiary {
         for(uint8 i = 0; i < scheduleList.length; i++) {
            schedules[i] = block.timestamp + scheduleList[i];
         }
         initialized = true;
    }
    
    function nextScheduleTime() external view whenInitialized returns(uint secondsLeft){
        uint time = schedules[nextScheduleId];
        uint nextTime = time - block.timestamp;
        if (time < block.timestamp) {
            revert ('distribute payment for previous round');
        } else {
            return nextTime;
        }
    }
    
    function endingTime() external view whenInitialized returns(uint secondsLeft){
        uint allTime = scheduleList.length;
        uint time = schedules[uint8(allTime) - 1];
        return time - block.timestamp;
        
    }

    function getSchedules() external view whenInitialized returns(uint[] memory schedule){
        return scheduleList;
    }
    
    function currentSchedule() external view whenInitialized returns(uint schedule){
        return scheduleList[nextScheduleId];
    }
    
    function getBalance(address userAddress, address tokenAddress) external view whenInitialized returns(uint){
        return balances[userAddress][tokenAddress];
    }
    
    function getBeneficiaries() external view returns(address[] memory beneficiary) {
        require(configured == true, 'Need to add beneficiaries first');
        return beneficiaries;
    }
    
    function percentageOf(address _beneficiary) external view returns(uint){
        return percentages[_beneficiary];
    }
    
    function _calculatePayment(address _beneficiary, address token, uint totalBalances) internal view returns(uint){
        uint balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, 'Empty pool');
        return percentages[_beneficiary] * (balance - totalBalances) / ((scheduleList.length - nextSubtract) / 100);
    }

    function distributePayment(address token) external whenInitialized {
        require(block.timestamp >= schedules[nextScheduleId], 'Realease time not reached');
        uint totalBalances;
        for(uint i = 0; i < beneficiaries.length; i++) {
            totalBalances = totalBalances + balances[beneficiaries[i]][token];
        } 
        for(uint i = 0; i < beneficiaries.length; i++){
            uint payment = _calculatePayment(beneficiaries[i], token, totalBalances);
            balances[beneficiaries[i]][token] = balances[beneficiaries[i]][token] + payment;
        }
        nextScheduleId++; 
        nextSubtract++;
        emit Distributed(token, msg.sender, nextScheduleId);
    }
    
    function withdrawPayment(address token) external whenInitialized onlyBeneficiary returns (bool success) {
        require(balances[msg.sender][token] > 0, 'No balance to withdraw'); 
        
        uint256 amount = balances[msg.sender][token];
        
        balances[msg.sender][token] = 0;
        
        IERC20(token).transfer(msg.sender, amount);
        
        emit Withdrawn(token, msg.sender, amount);
        return true;
    }
}