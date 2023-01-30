// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

contract Boii {

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
    uint256 constant MAX_NUMBER_OF_SHARES = 10**18;

    enum Vote {
        Null,
        Yes,
        No
    }

    //Member structure
    struct Member {
        uint256 shares;
        bool exists;
        uint256 highestIndexVote; 
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
        uint256 yesVoted;
        uint256 noVoted;
        bool[5] flags;
        string projectHash;
        uint256 maxTotalSharesAtYesVote;
        mapping(address => Vote) votesByMember;
    }
    
    //Internal contract variables
    uint256 public proposalCount;
    uint256 public totalShares;

    address public constant GUILD = address(0xdead);
    address public constant ESCROW = address(0xbeef);
    address public constant TOTAL = address(0xbabe);

    mapping (address => mapping (address => uint256)) public userTokenBalances;
    
    mapping(address => bool) public proposedToKick;
    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;

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

        members[_summoner] = Member(1, true, 0, false);
        totalShares = 1;

        // NOTE: The Moloch emit the deploy event.
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

    function getProposalFlags(uint256 proposalId) public view returns (bool[5] memory) {
        return proposals[proposalId].flags;
    }

    function getUserTokenBalance(address user, address token) public view returns (uint256) {
        return userTokenBalances[user][token];
    }

    // FIXME: Cannot use standard ABI, Is it okay to use experimentl version ABI v.2
    // function getAllProposals() public view returns () {
    //     string[] memory hash;
    //     uint256[] memory totalFundRequest;

    //     // for(uint256 i; i < proposalCount; i++) {

    //     // }
    //     return proposals;
    // }
    // function getSingleProposal(uint256 i) public view returns (Proposal memory) {
    //     return proposals[i];
    // }

    // FIXME: add check mechanism to see if the member has already voted. There are 2 ways
    // 1) add member address as optional parameter 
    // 2) create separate function
    // function getProposalById(uint256 proposalId) public view returns (
    //     address, //applicant
    //     address, //proposer
    //     address, //sponsor
    //     uint256, //sharesRequested
    //     uint256, //tributeOffered
    //     uint256, //paymentRequested
    //     uint256, //startPeriod
    //     uint256, //activePeriod
    //     uint256, //yesVoted 
    //     uint256, //noVoted
    //     bool[5] memory, //flags 
    //     string memory, //projectHash
    //     uint256 //maxTotalSharesAtYesVote
    // ) {        
    //     return (
    //         proposals[proposalId].applicant,
    //         proposals[proposalId].proposer,
    //         proposals[proposalId].sponsor,
    //         proposals[proposalId].sharesRequested,
    //         proposals[proposalId].tributeOffered,
    //         proposals[proposalId].paymentRequested,
    //         proposals[proposalId].startPeriod,
    //         proposals[proposalId].activePeriod,
    //         proposals[proposalId].yesVoted,
    //         proposals[proposalId].noVoted,
    //         proposals[proposalId].flags, 
    //         proposals[proposalId].projectHash,
    //         proposals[proposalId].maxTotalSharesAtYesVote
    //     );
    // }

    // SUBMIT PROPOSALS
    // function submitProposal(
    //     address applicant,
    //     uint256 sharesRequested,
    //     uint256 tributeOffered,
    //     uint256[] memory paymentRequested,
    //     string memory projectHash
    // ) public returns (uint256 proposalId) {
    //     require(sharesRequested + sharesRequested <= MAX_NUMBER_OF_SHARES, "too many shares requested");
    //     require(applicant != address(0), "applicant cannot be 0");
    //     require(applicant != GUILD && applicant != ESCROW && applicant != TOTAL, "applicant address cannot be reserved");
    //     require(members[applicant].jailed == false, "proposal applicant must not be jailed");

    //     // collect tribute from proposer and store it in the Moloch until the proposal is processed
    //     // require(IERC20(tributeToken).transferFrom(msg.sender, address(this), tributeOffered), "tribute token transfer failed");
    //     // unsafeAddToBalance(ESCROW, tributeToken, tributeOffered);

    //     bool[5] memory flags; // [sponsored, processed, didPass, cancelled, guildkick]

    //     _submitProposal(applicant, sharesRequested, tributeOffered, paymentRequested, projectHash, flags);
    //     return proposalCount - 1;
    // }

    function submitJoinProposal(
        address applicant,
        uint256 sharesRequested,
        uint256 tributeOffered,
        string memory details
    ) public returns(uint256 proposalId) {
        require(sharesRequested + sharesRequested <= MAX_NUMBER_OF_SHARES, "too many shares requested");
        require(applicant != address(0), "applicant cannot be 0");
        require(applicant != GUILD && applicant != ESCROW && applicant != TOTAL, "applicant address cannot be reserved");
        require(members[applicant].jailed == false, "proposal applicant must not be jailed");

        bool[5] memory flags = [false, false, false, false, false]; // [sponsored, processed, didPass, cancelled, guildkick]

        uint256[] memory paymentRequested = new uint256[](1); //join-request proposal is not required payment requested
        paymentRequested[0] = 0;

        _submitProposal(applicant, sharesRequested, tributeOffered, paymentRequested, details, flags);

        return proposalCount - 1;
    }

    function submitProjectProposal(
        address applicant,
        uint256 tributeOffered,
        uint256[] memory paymentRequested,
        string memory details
    ) public returns (uint256 proposalId) {
        require(applicant != address(0), "applicant cannot be 0");
        require(applicant != GUILD && applicant != ESCROW && applicant != TOTAL, "applicant address cannot be reserved");
        require(members[applicant].jailed == false, "proposal applicant must not be jailed");

        bool[5] memory flags = [false, false, false, false, false]; // [sponsored, processed, didPass, cancelled, guildkick]
        _submitProposal(applicant, 0, tributeOffered, paymentRequested, details, flags); // shares request is not required in project funding proposal

        return proposalCount - 1;
    }

    function submitGuildKickProposal(
        address memberToKick,
        string memory details
    ) public returns (uint256 proposalId) {
        Member memory member = members[memberToKick];

        require(member.shares > 0 , "member must have at least one share");
        require(members[memberToKick].jailed == false, "member must not already be jailed");

        bool[5] memory flags; // [sponsored, processed, didPass, cancelled, guildkick]
        flags[4] = true; // guild kick

        uint256[] memory _temp = new uint256[](1); // guildkick without paymentRequested
        _temp[0] = 0;

        _submitProposal(memberToKick, 0, 0, _temp, details, flags);
        return proposalCount - 1;
    }

    function _submitProposal(
        address applicant,
        uint256 sharesRequested, 
        uint256 tributeOffered, 
        uint256[] memory paymentRequested, 
        string memory projectHash, 
        bool[5] memory flags
    ) internal {
        Proposal storage proposal = proposals[proposalCount];
        proposal.applicant = applicant;
        proposal.proposer = msg.sender;
        proposal.sharesRequested = sharesRequested;
        proposal.tributeOffered = tributeOffered;
        proposal.paymentRequested = paymentRequested;
        proposal.startPeriod = [0];
        proposal.activePeriod = 0;
        proposal.yesVoted = 0;
        proposal.noVoted = 0;
        proposal.flags = flags;
        proposal.projectHash = projectHash;
        proposal.maxTotalSharesAtYesVote = 0;

        proposalCount += 1;
    } 

    function sponsorProposal(
        uint256 proposalId
    ) public {
        // collect proposal deposit from sponsor and store it in the Moloch until the proposal is processed
        // require(IERC20(depositToken).transferFrom(msg.sender, address(this), proposalDeposit), "proposal deposit token transfer failed");
        //unsafeAddToBalance(ESCROW, depositToken, proposalDeposit);

        Proposal storage proposal = proposals[proposalId];

        require(proposal.proposer != address(0), "proposal must have been proposed");
        require(!proposal.flags[0], "proposal has already been sponsored");
        require(!proposal.flags[3], "proposal has been cancelled");
        require(members[proposal.applicant].jailed == false, "proposal applicant must not be jailed");

        // guild kick proposal
        if (proposal.flags[4]) {
            require(!proposedToKick[proposal.applicant], "already proposed to kick");
            proposedToKick[proposal.applicant] = true;
        }

        // compute startingPeriod for proposal
        uint256 activePeriod = getCurrentPeriod() + 1;

        //set first period
        proposal.activePeriod = activePeriod;

        //set sponsor
        proposal.sponsor = msg.sender;

        //st flag
        proposal.flags[0] = true; // sponsored
    }

    function submitVote(uint256 proposalIndex, uint8 uintVote) public {
        Member storage member = members[msg.sender];

        require(proposalIndex < proposalCount, "proposal does not exist");
        Proposal storage proposal = proposals[proposalIndex];

        require(proposal.flags[0] == true, "proposal does not sponsor");
        require(uintVote < 3, "must be less than 3");
        Vote vote = Vote(uintVote);

        require(getCurrentPeriod() >= proposal.activePeriod, "voting period has not started");
        require(!hasVotingPeriodExpired(proposal.activePeriod), "proposal voting period has expired");
        require(proposal.votesByMember[msg.sender] == Vote.Null, "member has already voted");
        require(vote == Vote.Yes || vote == Vote.No, "vote must be either Yes or No");

        proposal.votesByMember[msg.sender] = vote;

        if (vote == Vote.Yes) {
            proposal.yesVoted = proposal.yesVoted + member.shares;

            // set maximum of total shares encountered at a yes vote - used to bound dilution for yes voters
            if (totalShares > proposal.maxTotalSharesAtYesVote) {
                proposal.maxTotalSharesAtYesVote = totalShares;
            }
        } else if (vote == Vote.No) {
            proposal.noVoted = proposal.noVoted + member.shares;
        }
    }

    function hasVotingPeriodExpired(uint256 startingPeriod) public view returns (bool) {
        return getCurrentPeriod() >= startingPeriod + votingPeriodLength;
    }

    function ragequit(uint256 sharesToBurn, uint256 proposalId) public {
        _ragequit(msg.sender, sharesToBurn, proposalId);
    }

    function _ragequit(address memberAddress, uint256 sharesToBurn, uint256 proposalId) internal {
        uint256 initialTotalShares = totalShares;

        Member storage member = members[memberAddress];

        require(member.shares >= sharesToBurn, "insufficient shares");

        // TODO: implement canRagequit function
        // require(canRagequit(memberAddress, proposalId), "cannot ragequit until highest index proposal member voted YES on is processed");

        // burn shares
        member.shares = member.shares - sharesToBurn;
        totalShares = totalShares - sharesToBurn;

        uint256 amountToRagequit = fairShare(userTokenBalances[GUILD][depositToken], sharesToBurn, initialTotalShares);
        if (amountToRagequit > 0) { // gas optimization to allow a higher maximum token limit
            // deliberately not using safemath here to keep overflows from preventing the function execution (which would break ragekicks)
            // if a token overflows, it is because the supply was artificially inflated to oblivion, so we probably don't care about it anyways
            userTokenBalances[GUILD][depositToken] -= amountToRagequit;
            userTokenBalances[memberAddress][depositToken] += amountToRagequit;
        }
    }

    // function canRagequit(address memberAddress, uint256 proposalId) internal view returns (bool) {
    //     return proposals[proposalId].votesByMember[memberAddress] != Vote(1);
    // }

    function cancelProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.flags[0], "proposal has already been sponsored");
        require(!proposal.flags[3], "proposal has already been cancelled");
        require(msg.sender == proposal.proposer, "solely the proposer can cancel");

        proposal.flags[3] = true; // cancelled

        // unsafeInternalTransfer(ESCROW, proposal.proposer, proposal.tributeToken, proposal.tributeOffered);
    }

    function getMemberProposalVote(address memberAddress, uint256 proposalId) public view returns (Vote) {
        require(members[memberAddress].exists, "member does not exist");
        return proposals[proposalId].votesByMember[memberAddress];
    }

    function unsafeAddToBalance(address user, address token, uint256 amount) internal {
        userTokenBalances[user][token] += amount;
        userTokenBalances[TOTAL][token] += amount;
    }

    function unsafeSubtractFromBalance(address user, address token, uint256 amount) internal {
        userTokenBalances[user][token] -= amount;
        userTokenBalances[TOTAL][token] -= amount;
    }

    function unsafeInternalTransfer(address from, address to, address token, uint256 amount) internal {
        unsafeSubtractFromBalance(from, token, amount);
        unsafeAddToBalance(to, token, amount);
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

}