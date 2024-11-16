// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IRewardsDistributor {
    event AssetConfigUpdated(
        address indexed asset,
        address indexed reward,
        uint256 oldEmission,
        uint256 newEmission,
        uint256 oldDistributionEnd,
        uint256 newDistributionEnd,
        uint256 assetIndex
    );

    event Accrued(
        address indexed asset,
        address indexed reward,
        address indexed user,
        uint256 assetIndex,
        uint256 userIndex,
        uint256 rewardsAccrued
    );

    function setDistributionEnd(
        address asset,
        address reward,
        uint32 newDistributionEnd
    ) external;

    function setEmissionPerSecond(
        address asset,
        address[] calldata rewards,
        uint88[] calldata newEmissionsPerSecond
    ) external;

    function getDistributionEnd(
        address asset,
        address reward
    ) external view returns (uint256);

    function getUserAssetIndex(
        address user,
        address asset,
        address reward
    ) external view returns (uint256);

    function getRewardsData(
        address asset,
        address reward
    ) external view returns (uint256, uint256, uint256, uint256);

    function getAssetIndex(
        address asset,
        address reward
    ) external view returns (uint256, uint256);

    function getRewardsByAsset(
        address asset
    ) external view returns (address[] memory);

    function getRewardsList() external view returns (address[] memory);

    function getUserAccruedRewards(
        address user,
        address reward
    ) external view returns (uint256);

    function getUserRewards(
        address[] calldata assets,
        address user,
        address reward
    ) external view returns (uint256);

    function getAllUserRewards(
        address[] calldata assets,
        address user
    ) external view returns (address[] memory, uint256[] memory);

    function getAssetDecimals(address asset) external view returns (uint8);

    function EMISSION_MANAGER() external view returns (address);

    function getEmissionManager() external view returns (address);
}
