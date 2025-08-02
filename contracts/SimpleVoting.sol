// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {

    uint public winningProposalId;
    WorkflowStatus public workflowStatus;
    Proposal[] public proposals;
    mapping(address => bool) public whitelist;
    mapping(address => Voter) public voters;
    

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint voteProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    constructor() Ownable(msg.sender) {
        // addToWhitelist(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        // addToWhitelist(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db);
        // addToWhitelist(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);
        // isWhitelisted(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);
        // startProposalsRegistration();
    }

    function addToWhitelist(address _address) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Registration not started");
        require(whitelist[_address] == false, "address is already in the whitelist");
        whitelist[_address] = true;
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    function startProposalsRegistration() public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Registering voters did not start");
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function getWorkflowStatus() public view returns(WorkflowStatus) {
        return workflowStatus;
    }

    function sendNewProposition(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Registration propositions did not started");
        require(whitelist[msg.sender], "You are not whitelisted");
        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length - 1);
    }

    function getAllProposals() external view returns(Proposal[] memory) {
        return proposals;
    }

    function getProposalByIndex(uint _index) external view returns(Proposal memory) {
          require(_index < proposals.length, "Proposal does not exist");
        return proposals[_index];
    }
    
    function endProposalsRegistration() public onlyOwner {
        require (workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not started");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded); 
    }

    function startVotingSession() public onlyOwner {
       require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Proposals registration not ended");
       workflowStatus = WorkflowStatus.VotingSessionStarted;
       emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted); 
    }

    function sendVote(uint _proposalIndex) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "registration did not started");
        require(_proposalIndex < proposals.length, "Proposal does not exist");
        Voter storage v = voters[msg.sender];
        require (v.isRegistered, "you are not registered");
        require(!v.hasVoted, "do you have already vote");
        Proposal storage p = proposals[_proposalIndex];
        p.voteCount++;
        v.hasVoted = true;
        v.voteProposalId = _proposalIndex;
        emit Voted(msg.sender, _proposalIndex);
    }
    
    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }
    
    // Penser a calculer les égalités et créer un nouvelle session de vote avec ces propositions
    function computeMostVotedproposal() public {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Voting session not ended");
        uint winningIndex;
        uint highestVoteCount;
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > highestVoteCount)
                winningIndex = i;
        }
        winningProposalId = winningIndex;
        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    function getMostVotedProposal() external view returns(Proposal memory) {
        return proposals[winningProposalId];
    }

}