// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    // Structures
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

    // Une session de vote identifiée par un uint sessionId
    struct VotingSession {
        WorkflowStatus workflowStatus;
        Proposal[] proposals;
        mapping(address => Voter) voters;
        uint winningProposalId;
    }

    constructor() Ownable(msg.sender) {
        
    }

    // Compteur de sessions
    uint public currentSessionId;

    // Mapping des sessions
    mapping(uint => VotingSession) private sessions;

    // Events globaux avec sessionId
    event VoterRegistered(uint sessionId, address voterAddress);
    event WorkflowStatusChange(uint sessionId, WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint sessionId, uint proposalId);
    event Voted(uint sessionId, address voter, uint proposalId);

    // -------- Gestion session --------

    // Démarrer une nouvelle session (reset automatique)
    function startNewSession() external onlyOwner {
        currentSessionId++;
        VotingSession storage session = sessions[currentSessionId];
        // Initialiser workflow au début
        session.workflowStatus = WorkflowStatus.RegisteringVoters;
        // Pas besoin de reset mapping, ils sont fresh par session
        emit WorkflowStatusChange(currentSessionId, WorkflowStatus.VotesTallied, WorkflowStatus.RegisteringVoters);
    }

    // Ajouter un votant dans une session
    function addToWhitelist(uint sessionId, address voter) external onlyOwner {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus == WorkflowStatus.RegisteringVoters, "Registration not started");
        require(!session.voters[voter].isRegistered, "Voter already registered");
        session.voters[voter] = Voter(true, false, 0);
        emit VoterRegistered(sessionId, voter);
    }

    function isWhitelisted(uint sessionId, address voter) public view returns (bool) {
        return sessions[sessionId].voters[voter].isRegistered;
    }

    // Démarrer inscription propositions
    function startProposalsRegistration(uint sessionId) external onlyOwner {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus == WorkflowStatus.RegisteringVoters, "Wrong workflow status");
        WorkflowStatus previous = session.workflowStatus;
        session.workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(sessionId, previous, WorkflowStatus.ProposalsRegistrationStarted);
    }

    // Ajouter une proposition
    function sendNewProposition(uint sessionId, string memory description) external {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals registration not started");
        require(session.voters[msg.sender].isRegistered, "You are not whitelisted");
        session.proposals.push(Proposal(description, 0));
        emit ProposalRegistered(sessionId, session.proposals.length - 1);
    }

    // Récupérer toutes les propositions d'une session
    function getAllProposals(uint sessionId) external view returns (Proposal[] memory) {
        return sessions[sessionId].proposals;
    }

    // Fin inscription propositions
    function endProposalsRegistration(uint sessionId) external onlyOwner {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Wrong workflow status");
        WorkflowStatus previous = session.workflowStatus;
        session.workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(sessionId, previous, WorkflowStatus.ProposalsRegistrationEnded);
    }

    // Démarrer session de vote
    function startVotingSession(uint sessionId) external onlyOwner {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Wrong workflow status");
        WorkflowStatus previous = session.workflowStatus;
        session.workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(sessionId, previous, WorkflowStatus.VotingSessionStarted);
    }

    // Voter
    function sendVote(uint sessionId, uint proposalIndex) external {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        require(proposalIndex < session.proposals.length, "Proposal does not exist");
        Voter storage voter = session.voters[msg.sender];
        require(voter.isRegistered, "You are not registered");
        require(!voter.hasVoted, "You have already voted");

        session.proposals[proposalIndex].voteCount++;
        voter.hasVoted = true;
        voter.voteProposalId = proposalIndex;
        emit Voted(sessionId, msg.sender, proposalIndex);
    }

    // Fin session de vote
    function endVotingSession(uint sessionId) external onlyOwner {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting session not started");
        WorkflowStatus previous = session.workflowStatus;
        session.workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(sessionId, previous, WorkflowStatus.VotingSessionEnded);
    }

    // Calculer gagnant
    function computeMostVotedProposal(uint sessionId) external onlyOwner {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus == WorkflowStatus.VotingSessionEnded, "Voting session not ended");

        uint winningIndex = 0;
        uint highestVoteCount = 0;
        for (uint i = 0; i < session.proposals.length; i++) {
            if (session.proposals[i].voteCount > highestVoteCount) {
                highestVoteCount = session.proposals[i].voteCount;
                winningIndex = i;
            }
        }
        session.winningProposalId = winningIndex;
        WorkflowStatus previous = session.workflowStatus;
        session.workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(sessionId, previous, WorkflowStatus.VotesTallied);
    }

    // Obtenir la proposition gagnante
    function getMostVotedProposal(uint sessionId) external view returns (Proposal memory) {
        VotingSession storage session = sessions[sessionId];
        require(session.workflowStatus >= WorkflowStatus.VotesTallied, "Votes not tallied");
        return session.proposals[session.winningProposalId];
    }
}
