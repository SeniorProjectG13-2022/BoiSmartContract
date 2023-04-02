// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "./IERC20.sol";
import "./ReentrancyGuard.sol";

contract Boii is ReentrancyGuard{

    //Global constants
    //custom constant that can set when deploy
    uint256 public periodDuration;
    uint256 public votingPeriodLength;
    uint256 public gracePeriodLength;
    uint256 public proposalDeposit;
    uint256 public dilutionBound;
    uint256 public summoningTime;

    address public depositToken; 

    //Hard-coded limition constants (using the default value of Moloch)
    uint256 constant MAX_VOTING_PERIOD_LENGTH = 10**18;
    uint256 constant MAX_GRACE_PERIOD_LENGTH = 10**18;
    uint256 constant MAX_DILUTION_BOUND = 10**18;
    uint256 constant MAX_NUMBER_OF_SHARES = 100;

    enum Vote {
        Null,
        Yes,
        No
    }

    //Member structure
    struct Member {
        uint256 shares;
        bool exists;
        bool jailed;
    }

    //Proposal structure
    struct Proposal {
        address applicant;
        address proposer;
        address sponsor;
        uint256 sharesRequested;
        uint256 tributeOffered;
        uint256[] paymentRequested;
        uint256[] startPeriod;
        uint256 activePeriod;
        uint256 milestoneIndex;
        uint256 yesVoted;
        uint256 noVoted;
        bool[6] flags;
        string projectHash;
        uint256 maxTotalSharesAtYesVote;
        // mapping(address => Vote) votesByMember;
        mapping(uint256 => mapping(address => Vote)) votesByMemberByMilestone;
    }
    
    //Internal contract variables
    uint256 public proposalCount;   //the number of proposals in smart contract
    uint256 public totalShares;     //total existed shares

    address public constant GUILD = address(0xdead);
    address public constant ESCROW = address(0xbeef);
    address public constant TOTAL = address(0xbabe);

    mapping (address => mapping (address => uint256)) public userTokenBalances;
    
    mapping(address => bool) public proposedToKick;         //list of member who proposed to be kicked
    mapping(address => Member) public members;              //all members
    mapping(uint256 => Proposal) public proposals;          //all proposals
    mapping(address => uint256) public totalMemberShares;   //share of each members includes shares requested from proposal. use this to limit the share per member

    // event for indexing all proposals status update
    event UpdateProposal(uint256 indexed proposalId, address proposer, string projectHash, uint256[] paymentRequest, bool[6] flags, uint256 yesVoted, uint256 noVoted, uint256 milestoneIndex);

    // Modifier
    modifier onlyMember {
        require(members[msg.sender].shares > 0, "not a member");
        _;
    }

    constructor(
        address _summoner,
        address _depositToken,
        uint256 _periodDuration,
        uint256 _votingPeriodLength,
        uint256 _gracePeriodLength,
        uint256 _proposalDeposit,
        uint256 _dilutionBound
    ) {
        require(_summoner != address(0), "summoner cannot be 0");
        require(_periodDuration > 0, "periodDuration must greater than 0");
        require(_votingPeriodLength > 0, "votingPeriodLength must greater than 0");
        require(_votingPeriodLength <= MAX_VOTING_PERIOD_LENGTH, "votingPeriodLength exceeds the limit");
        require(_gracePeriodLength > 0, "gracePeriodLength must greater than 0");
        require(_gracePeriodLength <= MAX_GRACE_PERIOD_LENGTH, "gracePeriodLength exceeds the limit");
        require(_dilutionBound > 0, "dilutionBound must greater than 0");
        require(_dilutionBound <= MAX_DILUTION_BOUND, "dilutionBound exceeds the limit");
        require(_depositToken != address(0), "depositToken cannot be 0");
        
        depositToken = _depositToken;
        periodDuration = _periodDuration;
        votingPeriodLength = _votingPeriodLength;
        gracePeriodLength = _gracePeriodLength;
        proposalDeposit = _proposalDeposit;
        dilutionBound = _dilutionBound;
        
        summoningTime = block.timestamp;

        members[_summoner] = Member(1, true, false);
        totalMemberShares[_summoner] = 1;
        totalShares = 1;
    }

    //Getter and helper function
    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x : y;
    }

    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp - summoningTime) / periodDuration;
    }

    function getPaymentRequested(uint256 proposalId) public view returns (uint256[] memory) {
        return proposals[proposalId].paymentRequested;
    }

    function getStartPeriod(uint256 proposalId) public view returns (uint256[] memory) {
        return proposals[proposalId].startPeriod;
    }

    function getProposalFlags(uint256 proposalId) public view returns (bool[6] memory) {
        return proposals[proposalId].flags;
    }

    function getUserTokenBalance(address user, address token) public view returns (uint256) {
        return userTokenBalances[user][token];
    }

    function submitJoinProposal(
        address applicant,
        uint256 sharesRequested,
        uint256 tributeOffered,
        string memory details
    ) public nonReentrant returns(uint256 proposalId) {
        require(sharesRequested + sharesRequested <= MAX_NUMBER_OF_SHARES, "too many shares requested");
        require(applicant != address(0), "applicant cannot be 0");
        require(applicant != GUILD && applicant != ESCROW && applicant != TOTAL, "applicant address cannot be reserved");
        require(members[applicant].jailed == false, "proposal applicant must not be jailed");
        require(totalMemberShares[applicant] + sharesRequested <= 9, "member must not have more than 9 shares");

        // collect tribute from proposer and store it in the smart contract until the proposal is processed
        require(IERC20(depositToken).transferFrom(msg.sender, address(this), tributeOffered), "tribute token transfer failed");
        unsafeAddToBalance(ESCROW, tributeOffered);

        bool[6] memory flags = [false, false, false, false, false, false]; // [sponsored, processed, didPass, cancelled, guildkick, preprocessed]

        uint256[] memory paymentRequested = new uint256[](1); //join-request proposal is not required payment requested
        paymentRequested[0] = 0;
        
        totalMemberShares[applicant] += sharesRequested;    //add temporary shares for checking limit to the applicant
        _submitProposal(applicant, sharesRequested, tributeOffered, paymentRequested, paymentRequested, details, flags); //second paymentRequested is start period which is not required in this kind of proposal

        return proposalCount - 1;
    }

    function submitProjectProposal(
        address applicant,
        uint256[] memory paymentRequested,
        uint256[] memory startPeriod,
        string memory details
    ) public nonReentrant returns (uint256 proposalId) {
        require(applicant != address(0), "applicant cannot be 0");
        require(applicant != GUILD && applicant != ESCROW && applicant != TOTAL, "applicant address cannot be reserved");
        require(members[applicant].jailed == false, "proposal applicant must not be jailed");
        
        bool[6] memory flags = [false, false, false, false, false, false]; // [sponsored, processed, didPass, cancelled, guildkick, preprocessed]
        _submitProposal(applicant, 0, 0, paymentRequested, startPeriod, details, flags); // shares request is not required in project funding proposal

        return proposalCount - 1;
    }

    function submitGuildKickProposal(
        address memberToKick,
        string memory details
    ) public nonReentrant returns (uint256 proposalId) {
        Member memory member = members[memberToKick];

        require(member.shares > 0 , "member must have at least one share");
        require(members[memberToKick].jailed == false, "member must not already be jailed");

        bool[6] memory flags; // [sponsored, processed, didPass, cancelled, guildkick, preprocessed]
        flags[4] = true; // set guildkick flag

        uint256[] memory _temp = new uint256[](1); // guildkick proposal don't need paymentRequested
        _temp[0] = 0;

        _submitProposal(memberToKick, 0, 0, _temp, _temp, details, flags);
        return proposalCount - 1;
    }

    function _submitProposal(
        address applicant,
        uint256 sharesRequested, 
        uint256 tributeOffered, 
        uint256[] memory paymentRequested, 
        uint256[] memory startPeriod,
        string memory projectHash, 
        bool[6] memory flags
    ) internal {
        Proposal storage proposal = proposals[proposalCount];
        proposal.applicant = applicant;
        proposal.proposer = msg.sender;
        proposal.sharesRequested = sharesRequested;
        proposal.tributeOffered = tributeOffered;
        proposal.paymentRequested = paymentRequested;
        proposal.startPeriod = startPeriod;
        proposal.activePeriod = 0;
        proposal.milestoneIndex = 0;
        proposal.yesVoted = 0;
        proposal.noVoted = 0;
        proposal.flags = flags;
        proposal.projectHash = projectHash;
        proposal.maxTotalSharesAtYesVote = 0;

        emit UpdateProposal(proposalCount, proposal.proposer, projectHash, paymentRequested, proposal.flags, proposal.yesVoted, proposal.noVoted, proposal.milestoneIndex);

        proposalCount += 1;
    } 

    function sponsorProposal(
        uint256 proposalId
    ) public nonReentrant onlyMember {
        // collect proposal deposit from sponsor and store it in the smart contract until the proposal is processed
        require(IERC20(depositToken).transferFrom(msg.sender, address(this), proposalDeposit), "proposal deposit token transfer failed");
        unsafeAddToBalance(ESCROW, proposalDeposit);

        Proposal storage proposal = proposals[proposalId];

        require(proposal.proposer != address(0), "proposal must have been proposed");
        require(!proposal.flags[0], "proposal has already been sponsored");
        require(!proposal.flags[3], "proposal has been cancelled");
        require(!proposal.flags[1], "proposal has been processed");
        require(members[proposal.applicant].jailed == false, "proposal applicant must not be jailed");

        // for guild kick proposal
        if (proposal.flags[4]) {
            require(!proposedToKick[proposal.applicant], "already proposed to kick");
            proposedToKick[proposal.applicant] = true;
        }

        // compute starting period for proposal
        // set active period to be next period
        if (proposal.milestoneIndex == 0) {
            proposal.startPeriod[0] = getCurrentPeriod() + 1;

            // set starting period for each milestone by plus the distancing period with the base period (active period)
            for (uint i=1; i < proposal.startPeriod.length; i++) {
                proposal.startPeriod[i] = proposal.startPeriod[i-1] + proposal.startPeriod[i];
            }
        }
        proposal.activePeriod = proposal.startPeriod[0];

        proposal.sponsor = msg.sender;  // set sponsor of the proposal

        proposal.flags[0] = true; // set sponsored flag

        emit UpdateProposal(proposalId, proposal.proposer, proposal.projectHash, proposal.paymentRequested, proposal.flags, proposal.yesVoted, proposal.noVoted, proposal.milestoneIndex);
    }

    function submitVote(uint256 proposalIndex, uint8 uintVote) public nonReentrant onlyMember {
        Member storage member = members[msg.sender];

        require(proposalIndex < proposalCount, "proposal does not exist");
        Proposal storage proposal = proposals[proposalIndex];

        require(proposal.flags[0] == true, "proposal does not sponsor");
        require(uintVote < 3, "must be less than 3");
        Vote vote = Vote(uintVote);

        require(getCurrentPeriod() >= proposal.activePeriod, "voting period has not started");
        require(!hasVotingPeriodExpired(proposal.activePeriod), "proposal voting period has expired");
        require(proposal.votesByMemberByMilestone[proposal.milestoneIndex][msg.sender] == Vote.Null, "member has already voted");
        require(vote == Vote.Yes || vote == Vote.No, "vote must be either Yes or No");

        proposal.votesByMemberByMilestone[proposal.milestoneIndex][msg.sender] = vote;
        // update Voting result
        if (vote == Vote.Yes) {
            proposal.yesVoted = proposal.yesVoted + member.shares;

            // set maximum of total shares encountered at a yes vote - used to bound dilution for yes voters
            if (totalShares > proposal.maxTotalSharesAtYesVote) {
                proposal.maxTotalSharesAtYesVote = totalShares;
            }
        } else if (vote == Vote.No) {
            proposal.noVoted = proposal.noVoted + member.shares;
        }

        emit UpdateProposal(proposalIndex, proposal.proposer, proposal.projectHash, proposal.paymentRequested, proposal.flags, proposal.yesVoted, proposal.noVoted, proposal.milestoneIndex);
    }

    function hasVotingPeriodExpired(uint256 startingPeriod) public view returns (bool) {
        return getCurrentPeriod() >= startingPeriod + votingPeriodLength;
    }

    function testAddJailedMember(address jailedOne) public {
        members[jailedOne] = Member(1, true, true);
        totalShares += 1;
    }

    function testAddMember(address member) public {
        members[member] = Member(1, true, false);
        totalShares += 1;
    }

    function testAddNoSharesMember(address noSharesMember) public {
        members[noSharesMember] = Member(0, true, false);
    }

    function testSetSponsorFlag(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        proposal.flags[0] = true;
    }

    function testCancelFlag(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        proposal.flags[3] = true;
    }

    function testProcessFlag(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        proposal.flags[1] = true;
    }

    function testPreProcessFlag(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        proposal.flags[5] = true;
    }

    function testSetMoreYesVote(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        proposal.yesVoted = 100;
        proposal.noVoted = 0;
    }

    function testExceedDilutionBound(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        proposal.maxTotalSharesAtYesVote = 100000000000000;
    }

    function testDeposit(uint256 amount) public {
        require(IERC20(depositToken).transferFrom(msg.sender, address(this), amount), "test deposit token transfer failed");
        unsafeAddToBalance(msg.sender, amount);
    }

    function preProcessProposal(uint256 proposalId) public nonReentrant {
        _validatePreProposalForProcessing(proposalId);
        bool didPass = _didPass(proposalId);
        
        Proposal storage proposal = proposals[proposalId];

        proposal.flags[5] = true; // set preprocessed to TRUE

        if (proposal.flags[4] != true) {
            if (proposal.paymentRequested[0] == 0) {
                if (totalShares + proposal.sharesRequested > MAX_NUMBER_OF_SHARES) {
                    didPass = false;
                }
                proposal.flags[2] = didPass;
            } else {
                if (proposal.paymentRequested[proposal.milestoneIndex] > userTokenBalances[GUILD][depositToken]) {
                    didPass = false;
                }
                proposal.flags[2] = didPass;
            }
        } else {
            proposal.flags[2] = didPass;
        }

        emit UpdateProposal(proposalId, proposal.proposer, proposal.projectHash, proposal.paymentRequested, proposal.flags, proposal.yesVoted, proposal.noVoted, proposal.milestoneIndex);
    }

    function processProposal(uint256 proposalId) public nonReentrant {
        _validateProposalForProcessing(proposalId);
        bool didPass = _didPass(proposalId);
        
        Proposal storage proposal = proposals[proposalId];
        // process proposal based on proposal type
        if (proposal.flags[4] != true) {
            if (proposal.paymentRequested[0] == 0) {
                _processJoinProposal(proposalId, didPass);
            } else {
                _processProjectProposal(proposalId, didPass);
            }
        } else {
            _processGuildKickProposal(proposalId, didPass);
        }
    }

    function _processJoinProposal(uint256 proposalId, bool isPass) internal {
        Proposal storage proposal = proposals[proposalId];
        bool didPass = isPass;

        // set processed flag
        proposal.flags[1] = true;

        // Make the proposal fail if the new total number of shares exceeds the limit
        if (totalShares + proposal.sharesRequested > MAX_NUMBER_OF_SHARES) {
            didPass = false;
        }

        if (didPass) {
            proposal.flags[2] = true; // set didPass flag

            // if the applicant is already a member, add to their existing shares
            if (members[proposal.applicant].exists) {
                members[proposal.applicant].shares = members[proposal.applicant].shares + proposal.sharesRequested;

            // the applicant is a new member, create a new record for them
            } else {
                members[proposal.applicant] = Member(proposal.sharesRequested, true, false);
            }
            // mint new shares
            totalShares = totalShares + proposal.sharesRequested;
            // transfer token temporary address to GUILD address (make thesse token to be assets of BOII)
            unsafeInternalTransfer(ESCROW, GUILD, proposal.tributeOffered);

        } else {
            proposal.flags[2] = false; // set didPass flag to false
            totalMemberShares[proposal.applicant] -= proposal.sharesRequested;  // reduce the temporary shares in case of failed proposal
            unsafeInternalTransfer(ESCROW, proposal.proposer, proposal.tributeOffered);
        }
        emit UpdateProposal(proposalId, proposal.proposer, proposal.projectHash, proposal.paymentRequested, proposal.flags, proposal.yesVoted, proposal.noVoted, proposal.milestoneIndex);
        // Transfer proposalDeposit back to sponsor
        _returnDeposit(proposal.sponsor);
    }

    function _processProjectProposal(uint256 proposalId, bool isPass) internal {
        Proposal storage proposal = proposals[proposalId];
        bool didPass = isPass;

        // set processed flag
        proposal.flags[1] = true;

        // Make the proposal fail if it is requesting more tokens as payment than the available guild bank balance
        if (proposal.paymentRequested[proposal.milestoneIndex] > userTokenBalances[GUILD][depositToken]) {
            didPass = false;
        }

        if (didPass) {
            proposal.flags[2] = true; //set didPass flag to true
            unsafeInternalTransfer(GUILD, proposal.applicant, proposal.paymentRequested[proposal.milestoneIndex]);

            // if there is another milestone
            if (proposal.startPeriod.length > proposal.milestoneIndex + 1) {
                // update active period and milestone index
                proposal.milestoneIndex += 1;
                proposal.activePeriod = proposal.startPeriod[proposal.milestoneIndex];
                // reset processed, preprocessed flag in case of the proposal has passed and the next milestone is existed
                proposal.flags[1] = false; //set processed flag to false
                proposal.flags[5] = false; //set preprocessed flag to false
                // reset votes result
                proposal.yesVoted = 0;
                proposal.noVoted = 0;
            }
        } else {
            proposal.flags[2] = false;  //set didPass flag to false
        }
        emit UpdateProposal(proposalId, proposal.proposer, proposal.projectHash, proposal.paymentRequested, proposal.flags, proposal.yesVoted, proposal.noVoted, proposal.milestoneIndex);
        
        // return the sponsoring cost to sponsor
        if (proposal.milestoneIndex == 0) {
            _returnDeposit(proposal.sponsor);
        }
    }

    function _processGuildKickProposal(uint256 proposalId, bool isPass) internal {
        Proposal storage proposal = proposals[proposalId];
        bool didPass = isPass;

        require(proposal.flags[4], "must be a guild kick proposal");

        // set processed flag
        proposal.flags[1] = true;

        // trigger ragekick function to burn all shares of the member
        if (didPass) {
            proposal.flags[2] = true;
            Member storage memberToKick = members[proposal.applicant];
            memberToKick.jailed = true;
            _ragekick(proposal.applicant);
            
        } else {
            proposal.flags[2] = false;
        }
        emit UpdateProposal(proposalId, proposal.proposer, proposal.projectHash, proposal.paymentRequested, proposal.flags, proposal.yesVoted, proposal.noVoted, proposal.milestoneIndex);
        proposedToKick[proposal.applicant] = false;
        _returnDeposit(proposal.sponsor);
    }

    function _validateProposalForProcessing(uint256 proposalId) internal view {
        require(proposalId < proposalCount, "proposal does not exist");
        Proposal storage proposal = proposals[proposalId];

        require(getCurrentPeriod() >= proposal.activePeriod + votingPeriodLength + gracePeriodLength, "proposal is not ready to be processed");
        require(proposal.flags[1] == false, "proposal has already been processed");
    }

    function _validatePreProposalForProcessing(uint256 proposalId) internal view {
        require(proposalId < proposalCount, "proposal does not exist");
        Proposal storage proposal = proposals[proposalId];

        require(getCurrentPeriod() >= proposal.activePeriod + votingPeriodLength, "proposal is not ready to be preprocessed");
        require(proposal.flags[1] == false && proposal.flags[5] == false, "proposal has already been preprocessed/processed");
    }

    function _didPass(uint256 proposalId) internal view returns (bool didPass) {
        Proposal storage proposal = proposals[proposalId];

        didPass = proposal.yesVoted > proposal.noVoted;

        // Make the proposal fail if the dilutionBound is exceeded
        if ((totalShares * dilutionBound) < proposal.maxTotalSharesAtYesVote) {
            didPass = false;
        }

        // Make the proposal fail if the applicant is jailed
        // - for standard proposals, we don't want the applicant to get any shares/loot/payment
        // - for guild kick proposals, we should never be able to propose to kick a jailed member (or have two kick proposals active), so it doesn't matter
        if (members[proposal.applicant].jailed != false) {
            didPass = false;
        }

        return didPass;
    }

    function _returnDeposit(address sponsor) internal {
        unsafeInternalTransfer(ESCROW, sponsor, proposalDeposit);
    }

    function ragequit(uint256 sharesToBurn, uint256 proposalId) public nonReentrant onlyMember {
        _ragequit(msg.sender, sharesToBurn, proposalId, false);
    }

    function _ragekick(address memberToKick) internal {
        Member storage member = members[memberToKick];

        require(member.jailed != false, "member must be in jail");
        require(member.shares > 0, "member must have some share"); // note - should be impossible for jailed member to have shares

        _ragequit(memberToKick, member.shares, 0, true);
    }

    function _ragequit(address memberAddress, uint256 sharesToBurn, uint256 proposalId, bool isKick) internal {
        uint256 initialTotalShares = totalShares;

        Member storage member = members[memberAddress];

        require(member.shares >= sharesToBurn, "insufficient shares");
        
        // member ragequit themself 
        if(!isKick) {
            require(proposals[proposalId].flags[5], "proposal must be preprocessed");
            require(getCurrentPeriod() < (proposals[proposalId].activePeriod + votingPeriodLength + gracePeriodLength), "proposal must be in grace period");
            require(proposals[proposalId].votesByMemberByMilestone[proposals[proposalId].milestoneIndex][memberAddress] != Vote(0), "member didn't vote on a proposal");
            require(proposals[proposalId].votesByMemberByMilestone[proposals[proposalId].milestoneIndex][memberAddress] != Vote(proposals[proposalId].flags[2] ? 1 : 2), "member who voted the same result cannot ragequit");
        }
        // burn shares
        member.shares = member.shares - sharesToBurn;
        totalMemberShares[memberAddress] -= sharesToBurn;
        totalShares = totalShares - sharesToBurn;

        uint256 amountToRagequit = fairShare(userTokenBalances[GUILD][depositToken], sharesToBurn, initialTotalShares);
        if (amountToRagequit > 0) {
            userTokenBalances[GUILD][depositToken] -= amountToRagequit;
            userTokenBalances[memberAddress][depositToken] += amountToRagequit;
        }
    }

    function cancelProposal(uint256 proposalId) public nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.flags[0], "proposal has already been sponsored");
        require(!proposal.flags[3], "proposal has already been cancelled");
        require(msg.sender == proposal.proposer, "solely the proposer can cancel");

        proposal.flags[3] = true; // cancelled
        totalMemberShares[proposal.applicant] -= proposal.sharesRequested;
        emit UpdateProposal(proposalId, proposal.proposer, proposal.projectHash, proposal.paymentRequested, proposal.flags, proposal.yesVoted, proposal.noVoted, proposal.milestoneIndex);
        unsafeInternalTransfer(ESCROW, proposal.proposer, proposal.tributeOffered);
    }

    // function getMemberProposalVote(address memberAddress, uint256 proposalId) public view returns (Vote) {
    //     require(members[memberAddress].exists, "member does not exist");
    //     return proposals[proposalId].votesByMember[memberAddress];
    // }

    function getMemberProposalVoteByMilestone(address memberAddress, uint256 proposalId, uint256 milestone) public view returns (Vote) {
        require(members[memberAddress].exists, "member doesn not exist");
        return proposals[proposalId].votesByMemberByMilestone[milestone][memberAddress];
    }

    function fairShare(uint256 balance, uint256 shares, uint256 totalShare) internal pure returns (uint256) {
        require(totalShare != 0);

        if (balance == 0) { return 0; }

        uint256 prod = balance * shares;

        if (prod / balance == shares) {
            return prod / totalShare;
        }
        return (balance / totalShare) * shares;
    }

    function withdrawBalance(uint256 amount) public nonReentrant {
        _withdrawBalance(amount);
    }

    function _withdrawBalance(uint256 amount) internal {
        require(userTokenBalances[msg.sender][depositToken] >= amount, "insufficient balance");
        unsafeSubtractFromBalance(msg.sender, amount);
        require(IERC20(depositToken).transfer(msg.sender, amount), "transfer failed");
    }

    function unsafeAddToBalance(address user, uint256 amount) internal {
        userTokenBalances[user][depositToken] += amount;
        userTokenBalances[TOTAL][depositToken] += amount;
    }

    function unsafeSubtractFromBalance(address user, uint256 amount) internal {
        userTokenBalances[user][depositToken] -= amount;
        userTokenBalances[TOTAL][depositToken] -= amount;
    }

    function unsafeInternalTransfer(address from, address to, uint256 amount) internal {
        unsafeSubtractFromBalance(from, amount);
        unsafeAddToBalance(to, amount);
    }

}