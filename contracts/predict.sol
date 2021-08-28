// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol"; //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol


contract FootballPrediction is Ownable {
    
    event NewFixture(bytes32 fixtureId, string gameId, uint date);
    event WithdrawWinnings(address player);

    address[] public players;
    address[] public winners;
    bytes32[] public fixtureIds;

    enum resultType {win, lose, draw, noResult} // refers to home team

    struct Fixture {
        string gameId; // e.g MNUCHE or ARSBRE
        uint date;
        uint16 homeScore;
        uint16 awayScore;
        resultType result;
    }

    struct Prediction {
        bytes32 fixtureId;
        uint16 homeScore;
        uint16 awayScore;
        resultType result;
    }

    mapping (bytes32 => Fixture) public fixtures;
    mapping (address => Prediction[]) public playerToPrediction;
    mapping (address => uint) public playerToAmountDue;

    function createFixture(string memory _game, uint _matchDate) external onlyOwner 
        returns (bytes32) {

        bytes32 fixtureId = keccak256(abi.encode(_game,_matchDate));
        fixtures[fixtureId] = Fixture(_game, _matchDate, 0, 0, resultType.noResult);
        fixtureIds.push(fixtureId);
        
        // Emit an event any time new fixture is created. UI code will listen to this and display
        emit NewFixture(fixtureId, _game, _matchDate);
        
        return fixtureId;
    }

    function balanceOfPot() public view returns (uint) {
        return address(this).balance;
    }
    
    function makePrediction(bytes32 _fixtureId, uint16 _homeScore, uint16 _awayScore)
        external payable {
        
        // Check _fixtureId is valid
        require(fixtures[_fixtureId].date != 0, "Fixture Id is invalid.");

        // Allow prediction entry only if it's entered before the match start time
        require(block.timestamp < fixtures[_fixtureId].date, "Predictions not allowed after match start.");
        
        // Make sure they paid :)
        require(msg.value > 0 ether, "Oops - please pay to play!");
        
        // Maintain a list of unique players and also a map of their address and prediction
        if (playerToPrediction[msg.sender].length == 0) {
            players.push(msg.sender);
        }

        resultType result;
        if (_homeScore == _awayScore) {
            result = resultType.draw;
        } else if (_homeScore > _awayScore) {
            result = resultType.win;
        } else {
            result = resultType.lose;
        }

        playerToPrediction[msg.sender].push(Prediction(_fixtureId, _homeScore, _awayScore, result));
    }

    function updateResultForMatch(bytes32 _fixtureId, uint16 _homeScore, uint16 _awayScore) external onlyOwner {
        Fixture storage matchToUpdate = fixtures[_fixtureId];
        matchToUpdate.homeScore = _homeScore;
        matchToUpdate.awayScore = _awayScore;
        
        if (_homeScore == _awayScore) {
            matchToUpdate.result = resultType.draw;
        } else if (_homeScore > _awayScore) {
            matchToUpdate.result = resultType.win;
        } else {
            matchToUpdate.result = resultType.lose;
        }
    }

    function calculateWinners() external onlyOwner {

        Prediction[] storage playerPredictions;

        for (uint i = 0; i < players.length; i++) {
            playerPredictions = playerToPrediction[players[i]];

            for (uint j = 0; i < playerPredictions.length; j++) {
                if (playerPredictions[j].result == fixtures[playerPredictions[j].fixtureId].result) {
                    winners.push(players[i]);
                }
            } //end of inner for loop
        } //end of outer for loop

        uint perMatchWinnings = balanceOfPot() / winners.length;

        for (uint i = 0; i < winners.length; i++) {
            playerToAmountDue[winners[i]] += perMatchWinnings;
        }

        // Delete fixtures once done to save storage
        for (uint i = 0; i < fixtureIds.length; i++) {
            delete fixtures[fixtureIds[i]];
        }
        delete fixtureIds;
    }

    function withdrawWinnings() public { 
        uint amount_due = playerToAmountDue[msg.sender];
        playerToAmountDue[msg.sender] = 0 ether;
        // https://solidity-by-example.org/sending-ether/
        (bool sent, bytes memory data) = payable(msg.sender).call{value: amount_due}("");
        require(sent, "Failed to send Ether");

        // Emit a withdraw winning event anytime a player withdraws. UI code will listen to this and take any action as needed
        emit WithdrawWinnings(msg.sender);
    }    
}