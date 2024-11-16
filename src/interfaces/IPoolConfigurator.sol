// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPoolConfigurator {
    event ReserveActive(address indexed asset, bool active);

    event ReserveInitialized(
        address indexed asset,
        address indexed aToken,
        address stableDebtToken,
        address variableDebtToken,
        address interestRateStrategyAddress
    );

    event ReserveBorrowing(address indexed asset, bool enabled);

    event EModeAssetCategoryChanged(
        address indexed asset,
        uint8 oldCategoryId,
        uint8 newCategoryId
    );

    event EModeCategoryAdded(
        uint8 indexed categoryId,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        address oracle,
        string label
    );

    event DebtCeilingChanged(
        address indexed asset,
        uint256 oldDebtCeiling,
        uint256 newDebtCeiling
    );

    event CollateralConfigurationChanged(
        address indexed asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    );

    event SiloedBorrowingChanged(
        address indexed asset,
        bool oldState,
        bool newState
    );

    function setReserveBorrowing(address asset, bool enabled) external;

    function configureReserveAsCollateral(
        address asset,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) external;

    function setAssetEModeCategory(address asset, uint8 newCategoryId) external;

    function setEModeCategory(
        uint8 categoryId,
        uint16 ltv,
        uint16 liquidationThreshold,
        uint16 liquidationBonus,
        address oracle,
        string calldata label
    ) external;

    function setDebtCeiling(address asset, uint256 newDebtCeiling) external;

    function setSiloedBorrowing(address asset, bool siloed) external;
}
