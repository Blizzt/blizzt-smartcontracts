// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../utils/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ITimelock.sol";

contract BlizztGovernorV1 is Ownable {
    
    struct Proposal {
        uint8 winnerOption;
        bytes32 merkleRoot;
    }

    mapping(uint32 => Proposal) private proposals;
    IERC20 private token;
    ITimelock private timelock;

    function init(address _token, address _timelock) external onlyOwner {
        token = IERC20(_token);
        timelock = ITimelock(_timelock);
    }

    function executeProposal(uint32 _proposalId, bytes32 _merkleRoot, uint8 _winnerOption, address[] calldata _targets, uint256[] calldata _values, string[] calldata _signatures, bytes[] calldata _datas, uint _eta) external onlyOwner  {
        require(_targets.length == _values.length, "");
        require(_targets.length == _signatures.length, "");
        require(_datas.length == _datas.length, "");

        proposals[_proposalId] = Proposal({
            winnerOption: _winnerOption,
            merkleRoot: _merkleRoot
        });

        for (uint i=0; i<_targets.length; i++) {
            timelock.queueTransaction(_targets[i], _values[i], _signatures[i], _datas[i], _eta);
        }
    }

    function cancelTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external onlyOwner {
        timelock.cancelTransaction(target, value, signature, data, eta);
    }

    function queueTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external returns(bytes32) {
        return timelock.queueTransaction(target, value, signature, data, eta);
    }

    function executeTransaction(address target, uint value, string calldata signature, bytes calldata data, uint eta) external payable onlyOwner returns (bytes memory) {
        return timelock.executeTransaction(target, value, signature, data, eta);
    }

    function validateProposalSignature(uint32 _proposalId, uint8 v, bytes32 r, bytes32 s) external view returns (bool) {
        return true;
    }

    function validateVoteSignature(uint8 v, bytes32 r, bytes32 s) external view returns(bool) {
        return true;
    }

    function verifyVote(uint32 _proposalId, uint256 _index, address _account, uint256 _voteId, bytes32[] calldata _merkleProof) external view returns(bool) {
        bytes32 node = keccak256(abi.encodePacked(_index, _account, _voteId));
        return MerkleProof.verify(_merkleProof, proposals[_proposalId].merkleRoot, node);
    }
}