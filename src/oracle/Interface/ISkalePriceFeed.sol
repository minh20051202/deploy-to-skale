// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISkalePriceFeed {
    // View function to get round data for a specific round ID
    function getRoundData(
        uint80 roundId
    )
        external
        view
        returns (
            uint80 roundId_,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    // View function to get data for the latest round
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId_,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    // View function to get the description of the feed
    function description() external view returns (string memory);

    // Function to transmit new data (only callable by the owner)
    function transmit(bytes32 _epochAndRound, bytes calldata report) external;

    // Function to request a new round (only callable by the owner)
    function requestNewRound() external returns (uint80);

    // Event emitted when a new round is requested
    event RoundRequested(address indexed requester, uint32 epoch, uint8 round);
}
