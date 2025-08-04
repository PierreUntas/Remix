// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    struct Proposal {
        uint proposalId; // à enlever
        string description;
        address submitter;
        uint voteCount;
    }

    struct Session {
        uint id;
        WorkflowStatus workflowStatus; // à mettre dans session pour multi
        uint proposalIdCounter;
        uint winningProposalId;
        uint highestVoteCount;
        Proposal[] proposals;
    }

    mapping(address => bool) public whitelist;
    mapping(uint => Session) private sessions;
    uint public sessionCounter;
    mapping(uint => mapping(address => bool)) private hasVotedInSession; // à ajouter pour gestion multi session

    // ======== EVENTS ==========
    event NewVotingSession(uint sessionId);
    event WorkflowStatusChange(uint sessionId, WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint sessionId, uint proposalId);
    event Voted(uint sessionId, address voter, uint proposalId);
    event WinnerDeclared(uint sessionId, uint proposalId);

    constructor() Ownable(msg.sender) {}

    // ===== Voters globaux =====
    function addToWhitelist(address _voter) external onlyOwner {
        require(!whitelist[_voter], "Already whitelisted");
        whitelist[_voter] = true;
    }

    function removeFromWhitelist(address _voter) external onlyOwner {
        require(whitelist[_voter], "Not in whitelist");
        whitelist[_voter] = false;
    }

    function isWhitelisted(address _voter) external view returns (bool) {
        return whitelist[_voter];
    }

    // ===== Sessions management =====
    function createSession() external onlyOwner {
        sessionCounter++;
        Session storage s = sessions[sessionCounter];
        s.id = sessionCounter;
        s.workflowStatus = WorkflowStatus.RegisteringVoters;
        emit NewVotingSession(sessionCounter);
    }

    function updateWorkflowStatus(uint sessionId, WorkflowStatus newStatus) internal {
        Session storage s = sessions[sessionId];
        emit WorkflowStatusChange(sessionId, s.workflowStatus, newStatus);
        s.workflowStatus = newStatus;
    }

    // ===== Proposal phase =====
    function startProposalsRegistration(uint sessionId) external onlyOwner {
        Session storage s = sessions[sessionId];
        require(s.workflowStatus == WorkflowStatus.RegisteringVoters, "Wrong workflow status");
        updateWorkflowStatus(sessionId, WorkflowStatus.ProposalsRegistrationStarted);
    }

    function sendNewProposition(uint sessionId, string calldata _description) external {
        Session storage s = sessions[sessionId];
        require(s.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Not proposal stage");
        require(whitelist[msg.sender], "Not whitelisted");
        require(bytes(_description).length > 0 && bytes(_description).length <= 256, "Invalid description size");

        uint newId = s.proposalIdCounter++;
        s.proposals.push(Proposal({
            proposalId: newId,
            description: _description,
            submitter: msg.sender,
            voteCount: 0
        }));
        emit ProposalRegistered(sessionId, newId);
    }

    function endProposalsRegistration(uint sessionId) external onlyOwner {
        Session storage s = sessions[sessionId];
        require(s.workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Not proposal stage");
        require(s.proposals.length > 0, "No proposals submitted");
        updateWorkflowStatus(sessionId, WorkflowStatus.ProposalsRegistrationEnded);
    }

    // ===== Voting phase =====
    function startVotingSession(uint sessionId) external onlyOwner {
        Session storage s = sessions[sessionId];
        require(s.workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Not ready for voting");
        updateWorkflowStatus(sessionId, WorkflowStatus.VotingSessionStarted);
    }

    function sendVote(uint sessionId, uint _proposalId) external {
        Session storage s = sessions[sessionId];
        require(s.workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting not started");
        require(whitelist[msg.sender], "Not whitelisted");
        require(!hasVotedInSession[sessionId][msg.sender], "Already voted in this session");
        require(_proposalId < s.proposals.length, "Invalid proposal ID");

        s.proposals[_proposalId].voteCount++;
        hasVotedInSession[sessionId][msg.sender] = true;

        if (s.proposals[_proposalId].voteCount > s.highestVoteCount) {
            s.highestVoteCount = s.proposals[_proposalId].voteCount;
        }
        emit Voted(sessionId, msg.sender, _proposalId);
    }

    function endVotingSession(uint sessionId) external onlyOwner {
        Session storage s = sessions[sessionId];
        require(s.workflowStatus == WorkflowStatus.VotingSessionStarted, "Voting not started");
        updateWorkflowStatus(sessionId, WorkflowStatus.VotingSessionEnded);
    }

    // ===== Compute winner =====
    function computeMostVotedProposal(uint sessionId) external onlyOwner {
        Session storage s = sessions[sessionId];
        require(s.workflowStatus == WorkflowStatus.VotingSessionEnded, "Voting session not ended");

        uint countBest = 0;
        for (uint i = 0; i < s.proposals.length; i++) {
            if (s.proposals[i].voteCount == s.highestVoteCount && s.highestVoteCount > 0) {
                countBest++;
            }
        }

        Proposal[] memory bestProposals = new Proposal[](countBest);
        uint index = 0;
        for (uint i = 0; i < s.proposals.length; i++) {
            if (s.proposals[i].voteCount == s.highestVoteCount && s.highestVoteCount > 0) {
                bestProposals[index++] = s.proposals[i];
            }
        }

        if (bestProposals.length == 1) {
            s.winningProposalId = bestProposals[0].proposalId;
            emit WinnerDeclared(sessionId, s.winningProposalId);
            updateWorkflowStatus(sessionId, WorkflowStatus.VotesTallied);
        } else {
            sessionCounter++;
            Session storage newSession = sessions[sessionCounter];
            newSession.id = sessionCounter;
            newSession.workflowStatus = WorkflowStatus.RegisteringVoters;

            for (uint i = 0; i < bestProposals.length; i++) {
                newSession.proposals.push(Proposal({
                    proposalId: i,
                    description: bestProposals[i].description,
                    submitter: bestProposals[i].submitter,
                    voteCount: 0
                }));
            }
            emit NewVotingSession(sessionCounter);
        }
    }

    // ===== Views =====
    function getAllProposalsBySession(uint sessionId) external view returns (Proposal[] memory) {
        return sessions[sessionId].proposals;
    }

    function hasVoted(uint sessionId, address voter) external view returns (bool) {
        return hasVotedInSession[sessionId][voter];
    }

    function getWorkflowStatus(uint sessionId) external view returns (WorkflowStatus) {
        return sessions[sessionId].workflowStatus;
    }
}
