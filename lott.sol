// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Lottery {
    struct Player {
        uint256 fid; // Player ID
        uint256 chances;
    }

    Player[] public players;
    uint256 public totalChances = 0;
    address public owner;

    constructor() {
        owner = msg.sender; // Set the owner to the address that deploys the contract
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Function to add players, restricted to onlyOwner
    function addPlayers(uint256[] calldata fids, uint256[] calldata chances) external onlyOwner {
        require(fids.length == chances.length, "Fids and chances length mismatch");

        for (uint i = 0; i < fids.length; i++) {
            players.push(Player({
                fid: fids[i],
                chances: chances[i]
            }));
            totalChances += chances[i];
        }
    }

    // Basic random number generator
    function random() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, totalChances)));
    }

    // Function to pick 10 winners, restricted to onlyOwner
    function pickWinners() external onlyOwner returns (uint256[10] memory) {
        uint256[10] memory winners;
        uint256 winnerCount = 0;
        uint256 drawChances = totalChances;

        while(winnerCount < 10) {
            uint256 rand = random() % drawChances;
            uint256 sum = 0;

            for (uint i = 0; i < players.length; i++) {
                sum += players[i].chances;
                if (rand < sum) {
                    bool alreadyWon = false;
                    for(uint j = 0; j < winnerCount; j++) {
                        if(winners[j] == players[i].fid) {
                            alreadyWon = true;
                            break;
                        }
                    }
                    if(!alreadyWon) {
                        winners[winnerCount] = players[i].fid;
                        winnerCount++;
                        break;
                    }
                }
            }
            drawChances = drawChances - sum;
        }

        return winners;
    }
}
