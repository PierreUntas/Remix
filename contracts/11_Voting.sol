// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {

    address public admin;
    uint public winningProposalId;
    uint private nonce;
    WorkflowStatus public workflowStatus;
    Proposal public mostVoted;
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
        admin = msg.sender;
    }
    
    function computeMostVotedproposal() public {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Voting session not ended");
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > mostVoted.voteCount)
                mostVoted = proposals[i];
        }
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    function getMostVotedProposal() external view returns(Proposal memory) {
        return mostVoted;
    }

    function addToWhitelist(address _address) public payable onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Registration not started");
        whitelist[_address] = true;
    }

    function startProposalsRegistration() public payable onlyOwner {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function sendNewProposition(string memory _description) public payable {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "registration did not started");
        require(whitelist[msg.sender], "You are not whitelisted");
        nonce++;
        proposals.push(Proposal(nonce, _description, 0));
    }

    function endProposalsRegistration() public onlyOwner {
        require (workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not started");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded); 
    }

    function startVotingSession() public onlyOwner {
       require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Proposals registration not ended");
       workflowStatus = WorkflowStatus.VotingSessionStarted;
    }

    function sendVote(uint _proposalId) public payable {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "registration did not started");
        Voter storage v = voters[msg.sender];
        require(!v.hasVoted, "do you have already vote");
        Proposal storage p = proposals[_proposalId];
        p.voteCount++;
        v.hasVoted = true;
    }

    function endVotingSession() public onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }
}