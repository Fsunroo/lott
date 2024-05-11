// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Lottery {
    struct Player {
        address addr;
        uint256 chances;
    }

    struct WinnerDetail {
        address winnerAddress;
        uint256 prizeAmount;
    }

    struct Round {
        uint256 ticketPrice;
        uint256 totalCollected;
        uint256 totalPlayers;
        uint256 totalChances;
        bool isActive;
        WinnerDetail[] winnerDetails;
    }

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => Player[]) public roundPlayers;
    uint256 public currentRoundId;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function startRound(uint256 _ticketPrice) external onlyOwner {
        require(currentRoundId == 0 || !rounds[currentRoundId].isActive, "Previous round still active");
        currentRoundId++;
        Round storage newRound = rounds[currentRoundId];
        newRound.ticketPrice = _ticketPrice;
        newRound.isActive = true;
    }

    function buyTickets(uint256 numTickets) external payable {
        require(rounds[currentRoundId].isActive, "No active round");
        require(msg.value == numTickets * rounds[currentRoundId].ticketPrice, "Incorrect amount sent");

        Player[] storage players = roundPlayers[currentRoundId];
        bool found = false;

        for (uint i = 0; i < players.length; i++) {
            if (players[i].addr == msg.sender) {
                players[i].chances += numTickets;
                found = true;
                break;
            }
        }
        
        if (!found) {
            players.push(Player({
                addr: msg.sender,
                chances: numTickets
            }));
            rounds[currentRoundId].totalPlayers++;
        }

        rounds[currentRoundId].totalCollected += msg.value;
        rounds[currentRoundId].totalChances += numTickets;
    }

    function pickWinners() view private returns (WinnerDetail[] memory) {
        require(rounds[currentRoundId].isActive, "No active round");
        require(roundPlayers[currentRoundId].length >= 10, "Not enough players to pick 10 winners");

        Player[] storage players = roundPlayers[currentRoundId];
        uint[] memory indices = new uint[](10);
        WinnerDetail[] memory details = new WinnerDetail[](10);
        uint totalChances = rounds[currentRoundId].totalChances;
        uint winnersCount = 0;

        while (winnersCount < 10) {
            uint r = uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, winnersCount))) % totalChances;
            uint cumulative = 0;

            for (uint i = 0; i < players.length; i++) {
                cumulative += players[i].chances;
                if (r < cumulative) {
                    indices[winnersCount] = i;
                    totalChances -= players[i].chances;
                    winnersCount++;
                    break;
                }
            }
        }

        uint ownerPrize = rounds[currentRoundId].totalCollected / 10;
        uint remainingPrize = rounds[currentRoundId].totalCollected - ownerPrize;
        uint[] memory prizes = new uint[](10);
        prizes[0] = remainingPrize * 30 / 100;  // 1st
        prizes[1] = remainingPrize * 20 / 100;  // 2nd
        prizes[2] = remainingPrize * 15 / 100;  // 3rd
        prizes[3] = remainingPrize * 10 / 100;  // 4th
        for (uint i = 4; i < 10; i++) {
            prizes[i] = remainingPrize * 25 / 6 / 100; // Evenly split the remaining 25%
        }

        for (uint i = 0; i < indices.length; i++) {
            details[i] = WinnerDetail({
                winnerAddress: players[indices[i]].addr,
                prizeAmount: prizes[i]
            });
        }

        return details;
    }

    function givePrizes() external onlyOwner {
        require(rounds[currentRoundId].isActive, "No active round");
        WinnerDetail[] memory winners = pickWinners();
        Round storage round = rounds[currentRoundId];
        for (uint i = 0; i < winners.length; i++) {
            payable(winners[i].winnerAddress).transfer(winners[i].prizeAmount);
        }
        payable(owner).transfer(round.totalCollected / 10); // Transfer 10% to the owner

        // Manual copying of winner details to storage
        delete round.winnerDetails; // Clear the existing array
        for (uint i = 0; i < winners.length; i++) {
            round.winnerDetails.push(winners[i]);
        }

        round.isActive = false; // Deactivate the round
    }

    function isAnyRoundActive() public view returns (bool) {
        if (currentRoundId == 0) return false;
        return rounds[currentRoundId].isActive;
    }

    function getRoundDetails(uint256 roundId) public view returns (uint256, uint256, uint256, uint256, bool) {
        Round storage round = rounds[roundId];
        return (
            round.ticketPrice,
            round.totalCollected,
            round.totalPlayers,
            round.totalChances,
            round.isActive
        );
    }

    function getWinnerCount(uint256 roundId) public view returns (uint256) {
        return rounds[roundId].winnerDetails.length;
    }

    function getWinnerDetail(uint256 roundId, uint256 winnerIndex) public view returns (address, uint256) {
        WinnerDetail storage winner = rounds[roundId].winnerDetails[winnerIndex];
        return (winner.winnerAddress, winner.prizeAmount);
    }

    function getPlayerDetails(uint256 roundId, address playerAddress) public view returns (uint256 chances, uint256 index) {
        Player[] storage players = roundPlayers[roundId];
        for (uint i = 0; i < players.length; i++) {
            if (players[i].addr == playerAddress) {
                return (players[i].chances , i);
            }
        }
        revert("Player not found in the specified round.");
    }

    function cancelRound() external onlyOwner {
        require(rounds[currentRoundId].isActive, "No active round to cancel");

        Round storage round = rounds[currentRoundId];
        Player[] storage players = roundPlayers[currentRoundId];

        // Refund each player's money
        if (players.length > 0) {
            for (uint i = 0; i < players.length; i++) {
                uint256 refundAmount = players[i].chances * round.ticketPrice;
                payable(players[i].addr).transfer(refundAmount);
            }
    }

        // Reset the winner details
        delete round.winnerDetails;
        for (uint i = 0; i < 10; i++) {
            round.winnerDetails.push(WinnerDetail({
                winnerAddress: 0x0000000000000000000000000000000000000000, // Placeholder address
                prizeAmount: 0
            }));
        }

        round.isActive = false; // Deactivate the round
    }

}
