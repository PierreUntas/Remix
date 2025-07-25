// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Voting is Ownable {

    // Define admin
    address public admin;
    constructor() Ownable(msg.sender) {
        admin = msg.sender;
    }

    // State variables
    uint public winningProposalId;
    mapping(address => bool) public whitelist;
    uint private nonce;
    Proposal[] public proposals;
    mapping(address => Voter) public voters;
    WorkflowStatus public workflowStatus;
    Proposal public mostVoted;

    // Structs
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

    // Enums
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    // Events
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    
    function computeMostVotedproposal() public {
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.ProposalsRegistrationEnded);

        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > mostVoted.voteCount)
                mostVoted = proposals[i];
        }
    }

    // Functions
    function getMostVotedProposal() external view returns(Proposal memory) {
        return mostVoted;
    }

    // Process
    // -------
    // Voter registration
    function addToWhitelist(address _address) public onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Registration not started");
        whitelist[_address] = true;
    }

    // Starting the proposal registration
    function startProposalsRegistration() public onlyOwner {
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    // Voters can make new proposals
    function sendNewProposition(string memory _description) public {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "registration did not started");
        require(whitelist[msg.sender], "You are not whitelisted");
        nonce++;
        proposals[nonce] = Proposal(nonce, _description, 0);   
    }

    // Stopping the proposal registration
    function endProposalsRegistration() public onlyOwner {
        require (workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not started");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded); 
    }

    // Voting session begins
    function startVotingSession() public onlyOwner {
       require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Proposals registration not ended");
       workflowStatus = WorkflowStatus.VotingSessionStarted;
    }

    // Voters can vote for a proposal
    function sendVote(uint _proposalId) public view {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "registration did not started");
        Voter memory v = voters[msg.sender];
        require(!v.hasVoted, "do you have already vote");
        Proposal memory p = proposals[_proposalId];
        p.voteCount++;
        v.hasVoted = true;
    }

    // Voting session ends
    function endVotingSession() public onlyOwner {
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }
}