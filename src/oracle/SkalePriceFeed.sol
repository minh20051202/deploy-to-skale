// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SkalePriceFeed is Ownable {
    string internal s_description;

    uint8 public immutable decimals;
    address private immutable i_owner;

    struct Configures {
        uint40 latestEpochAndRound;
        uint32 latestAggregatorRoundId;
    }

    Configures internal configures;

    struct Transmission {
        int192 answer;
        uint32 observationsTimestamp;
        uint32 transmissionTimestamp;
    }
    mapping(uint32 /* aggregator round ID */ => Transmission)
        internal transmissions;

    event RoundRequested(address indexed requester, uint32 epoch, uint8 round);

    constructor(
        uint8 decimals_,
        string memory description_,
        address owner
    ) Ownable(owner) {
        decimals = decimals_;
        s_description = description_;
        i_owner = owner;
    }

    function getRoundData(
        uint80 roundId
    )
        public
        view
        returns (
            uint80 roundId_,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        if (roundId > type(uint32).max) {
            return (0, 0, 0, 0, 0);
        }
        Transmission memory transmission = transmissions[uint32(roundId)];
        return (
            roundId,
            transmission.answer,
            transmission.observationsTimestamp,
            transmission.transmissionTimestamp,
            roundId
        );
    }

    function latestRoundData()
        public
        view
        returns (
            uint80 roundId_,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        uint32 latestAggregatorRoundId = configures.latestAggregatorRoundId;

        Transmission memory transmission = transmissions[
            latestAggregatorRoundId
        ];
        return (
            latestAggregatorRoundId,
            transmission.answer,
            transmission.observationsTimestamp,
            transmission.transmissionTimestamp,
            latestAggregatorRoundId
        );
    }

    function description() public view returns (string memory) {
        return s_description;
    }

    function transmit(
        bytes32 _epochAndRound,
        bytes calldata report
    ) external onlyOwner {
        uint40 epochAndRound = uint40(uint256(_epochAndRound));

        Configures memory _configures = configures;

        require(
            _configures.latestEpochAndRound < epochAndRound,
            "stale report"
        );

        update(_configures, epochAndRound, report);
    }

    function requestNewRound() external onlyOwner returns (uint80) {
        uint40 latestEpochAndRound = configures.latestEpochAndRound;
        uint32 latestAggregatorRoundId = configures.latestAggregatorRoundId;

        emit RoundRequested(
            msg.sender,
            uint32(latestEpochAndRound >> 8),
            uint8(latestEpochAndRound)
        );

        return latestAggregatorRoundId + 1;
    }

    function update(
        Configures memory _configures,
        uint40 epochAndround,
        bytes memory rawData
    ) internal {
        uint32 observationsTimestamp;
        int192 observation;

        _configures.latestEpochAndRound = epochAndround;
        _configures.latestAggregatorRoundId++;

        (observationsTimestamp, observation) = abi.decode(
            rawData,
            (uint32, int192)
        );

        transmissions[_configures.latestAggregatorRoundId] = Transmission({
            answer: observation,
            observationsTimestamp: observationsTimestamp,
            transmissionTimestamp: uint32(block.timestamp)
        });

        configures = _configures;
    }
}
