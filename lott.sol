// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Lottery {
    struct Player {
        address addr; // Player's Ethereum address
        uint256 chances;
    }

    Player[] public players;
    uint256 public totalChances = 0;
    uint256 public ticketPrice;
    uint256 public totalCollected = 0;
    mapping(uint => bool) private isWinner;
    mapping(address => uint) public playerIndex;
    address public owner;

    uint[] public winners;
    bool public winnersPicked = false;

    constructor(uint256 _ticketPrice) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function setTicketPrice(uint256 _ticketPrice) external onlyOwner {
        ticketPrice = _ticketPrice;
    }

    function buyTickets(uint256 numTickets) external payable {
        require(msg.value == numTickets * ticketPrice, "Incorrect amount sent");
        if (playerIndex[msg.sender] == 0) {
            playerIndex[msg.sender] = players.length + 1;
            players.push(Player({addr: msg.sender, chances: numTickets}));
        } else {
            players[playerIndex[msg.sender] - 1].chances += numTickets;
        }
        totalChances += numTickets;
        totalCollected += msg.value;
    }

    function random(uint seed) private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, seed)));
    }

    function pickWinners() private returns (uint[] memory) {
        require(players.length >= 10, "Not enough players to pick 10 winners");
        uint[] memory _winners = new uint[](10);
        uint remainingChances = totalChances;
        uint winnersCount = 0;

        while (winnersCount < 10) {
            uint r = random(winnersCount) % remainingChances;
            uint cumulative = 0;

            for (uint i = 0; i < players.length; i++) {
                if (!isWinner[i]) {
                    cumulative += players[i].chances;
                    if (r < cumulative) {
                        _winners[winnersCount] = i;
                        isWinner[i] = true;
                        remainingChances -= players[i].chances;
                        winnersCount++;
                        break;
                    }
                }
            }
        }
        winners = _winners; // Assign to the public array
        winnersPicked = true;
        return winners;
    }

    function givePrizes() external onlyOwner {
        require(!winnersPicked, "Winners have already been picked and awarded");
        uint[] memory _winners = pickWinners();
        uint ownerPrize = (totalCollected * 10) / 100;
        uint remainingPrize = totalCollected - ownerPrize;
        uint[] memory prizes = new uint[](10);
        prizes[0] = (remainingPrize * 30) / 100;  // 1st
        prizes[1] = (remainingPrize * 20) / 100;  // 2nd
        prizes[2] = (remainingPrize * 15) / 100;  // 3rd
        prizes[3] = (remainingPrize * 10) / 100;  // 4th
        for (uint i = 4; i < 10; i++) { // 5th to 10th
            prizes[i] = (remainingPrize * 25) / (10 - 4) / 100; // Evenly split the remaining 25%
        }

        for (uint i = 0; i < _winners.length; i++) {
            payable(players[_winners[i]].addr).transfer(prizes[i]);
            isWinner[_winners[i]] = false; // Reset winner status if needed
        }
        payable(owner).transfer(ownerPrize); // Transfer 10% to the owner
        totalCollected = 0; // Reset the collected amount
    }

    function getWinners() public view returns (uint[] memory) {
        if (winnersPicked) {
            return winners;
        } else {
            revert("Winners have not been picked yet, the game is still running.");
        }
    }
}
