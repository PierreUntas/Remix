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
        RegisteringVoters, // Inscription des électeurs
        ProposalsRegistrationStarted, // Enregistrement des propositions commencé
        ProposalsRegistrationEnded, // Enregistrement des propositions terminé
        VotingSessionStarted, // Session de vote commencée
        VotingSessionEnded, // Session de vote terminée
        VotesTallied // Votes comptabilisés
    }

    // Events
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // Functions
    function sendNewProposition(string memory _description) public {
        nonce++;
        proposals[nonce] = Proposal(nonce, _description, 0);   
    }

    function sendVote(uint _proposalId) public view {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "registration did not started");
        Voter memory v = voters[msg.sender];
        require(!v.hasVoted, "do you have already vote");
        Proposal memory p = proposals[_proposalId];
        p.voteCount++;
        v.hasVoted = true;
    }

    function getMostVotedProposal() public view returns(Proposal memory) {
        Proposal memory mostVoted = proposals[0];

        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > mostVoted.voteCount)
                mostVoted = proposals[i];
        }

        return mostVoted;
    }

    // Processus
    // ------------------------------------
    function addToWhitelist(address _address) public { 
        whitelist[_address] = true;
    }

    function registeringVoters() public {
        require(msg.sender == admin, "You are not the admin");
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function proposalsRegistrationEnded() public {
        require(msg.sender == admin, "You are not the admin");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
    }
    // ------------------------------------

    
}
