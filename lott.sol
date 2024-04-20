// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Lottery {
    struct Player {
        uint256 fid; // Player ID
        uint256 chances;
    }

    Player[] public players;
    uint256 public totalChances = 0;
    mapping(uint => bool) private isWinner;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function addPlayers(uint256[] calldata fids, uint256[] calldata chances) external onlyOwner {
        require(fids.length == chances.length, "Fids and chances length mismatch");

        for (uint i = 0; i < fids.length; i++) {
            players.push(Player({fid: fids[i], chances: chances[i]}));
            totalChances += chances[i];
        }
    }

 function random(uint seed) private view returns (uint) {
    return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, seed)));
}


    // Updated pickWinners function that safely handles output
    function pickWinners() public returns (uint[] memory) {
        require(players.length >= 10, "Not enough players to pick 10 winners");
        uint[] memory winners = new uint[](10);
        uint remainingChances = totalChances;
        uint winnersCount = 0;

        while (winnersCount < 10) {
            uint r = random(winnersCount) % remainingChances;
            uint cumulative = 0;

            for (uint i = 0; i < players.length; i++) {
                if (!isWinner[i]) { // Only consider players who haven't won yet
                    cumulative += players[i].chances;
                    if (r < cumulative) {
                        winners[winnersCount] = players[i].fid;
                        isWinner[i] = true; // Mark this player as a winner
                        remainingChances -= players[i].chances; // Reduce the pool of chances
                        winnersCount++;
                        break;
                    }
                }
            }
        }

        // Reset isWinner mapping for future draws (optional depending on use case)
        for (uint i = 0; i < winners.length; i++) {
            isWinner[winners[i]] = false;
        }

        return winners;
    }

}
