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
        uint id;
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
    }

    function addToWhitelist(address _address) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Registration not started");
        whitelist[_address] = true;
        Voter storage voter = voters[_address];
        voter.isRegistered = true;
        emit VoterRegistered(_address);

    }

    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    function startProposalsRegistration() public onlyOwner {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function sendNewProposition(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "registration did not started");
        require(voters[msg.sender].isRegistered, "You are not registered");
        uint newProposalId = proposals.length;
        proposals.push(Proposal(newProposalId, _description, 0));
        emit ProposalRegistered(newProposalId);
    }

    function getAllProposals() external view returns(Proposal[] memory) {
        return proposals;
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
    
    function sendVote(uint _proposalId) public {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "registration did not started");
        Voter storage voter = voters[msg.sender];
        require(!voter.hasVoted, "do you have already vote");
        Proposal storage proposal = proposals[_proposalId];
        proposal.voteCount++;
        voter.hasVoted = true;
        voter.voteProposalId = _proposalId;
    }


    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    // Dans la V1 => Penser a calculer les égalités et créer une nouvelle session de vote avec ces propositions
    function computeMostVotedproposal2() public {
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