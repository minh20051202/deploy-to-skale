// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPoolAddressesProvider} from "../interfaces/IPoolAddressesProvider.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PoolAddressesProvider is Ownable, IPoolAddressesProvider {
    string private _marketId;

    mapping(bytes32 => address) private _addresses;

    bytes32 private constant POOL = "POOL";
    bytes32 private constant POOL_CONFIGURATOR = "POOL_CONFIGURATOR";
    bytes32 private constant PRICE_ORACLE = "PRICE_ORACLE";
    bytes32 private constant ACL_MANAGER = "ACL_MANAGER";
    bytes32 private constant ACL_ADMIN = "ACL_ADMIN";
    bytes32 private constant PRICE_ORACLE_SENTINEL = "PRICE_ORACLE_SENTINEL";
    bytes32 private constant DATA_PROVIDER = "DATA_PROVIDER";

    constructor(string memory marketId, address owner) Ownable(owner) {
        _setMarketId(marketId);
        transferOwnership(owner);
    }

    function getMarketId() external view override returns (string memory) {
        return _marketId;
    }

    function setMarketId(
        string memory newMarketId
    ) external override onlyOwner {
        _setMarketId(newMarketId);
    }

    function getContractAddress(
        bytes32 id
    ) public view override returns (address) {
        return _addresses[id];
    }

    function setAddress(
        bytes32 id,
        address newAddress
    ) external override onlyOwner {
        address oldAddress = _addresses[id];
        _addresses[id] = newAddress;
        emit AddressSet(id, oldAddress, newAddress);
    }

    function setAddressAsProxy(
        bytes32 id,
        address newImplementationAddress
    ) external override onlyOwner {}

    function getPool() external view override returns (address) {
        return getContractAddress(POOL);
    }

    function setPoolImpl(address newPoolImpl) external override onlyOwner {
        address oldPoolImpl = _addresses[POOL];
        _addresses[POOL] = newPoolImpl;
        emit PoolUpdated(oldPoolImpl, newPoolImpl);
    }

    function getPoolConfigurator() external view override returns (address) {
        return getContractAddress(POOL_CONFIGURATOR);
    }

    function setPoolConfiguratorImpl(
        address newPoolConfiguratorImpl
    ) external override onlyOwner {
        address oldPoolConfiguratorImpl = _addresses[POOL_CONFIGURATOR];
        _addresses[POOL_CONFIGURATOR] = newPoolConfiguratorImpl;
        emit PoolConfiguratorUpdated(
            oldPoolConfiguratorImpl,
            newPoolConfiguratorImpl
        );
    }

    function getPriceOracle() external view override returns (address) {
        return getContractAddress(PRICE_ORACLE);
    }

    function setPriceOracle(
        address newPriceOracle
    ) external override onlyOwner {
        address oldPriceOracle = _addresses[PRICE_ORACLE];
        _addresses[PRICE_ORACLE] = newPriceOracle;
        emit PriceOracleUpdated(oldPriceOracle, newPriceOracle);
    }

    function getACLManager() external view override returns (address) {
        return getContractAddress(ACL_MANAGER);
    }

    function setACLManager(address newAclManager) external override onlyOwner {
        address oldAclManager = _addresses[ACL_MANAGER];
        _addresses[ACL_MANAGER] = newAclManager;
        emit ACLManagerUpdated(oldAclManager, newAclManager);
    }

    function getACLAdmin() external view override returns (address) {
        return getContractAddress(ACL_ADMIN);
    }

    function setACLAdmin(address newAclAdmin) external override onlyOwner {
        address oldAclAdmin = _addresses[ACL_ADMIN];
        _addresses[ACL_ADMIN] = newAclAdmin;
        emit ACLAdminUpdated(oldAclAdmin, newAclAdmin);
    }

    function getPriceOracleSentinel() external view override returns (address) {
        return getContractAddress(PRICE_ORACLE_SENTINEL);
    }

    function setPriceOracleSentinel(
        address newPriceOracleSentinel
    ) external override onlyOwner {
        address oldPriceOracleSentinel = _addresses[PRICE_ORACLE_SENTINEL];
        _addresses[PRICE_ORACLE_SENTINEL] = newPriceOracleSentinel;
        emit PriceOracleSentinelUpdated(
            oldPriceOracleSentinel,
            newPriceOracleSentinel
        );
    }

    function getPoolDataProvider() external view override returns (address) {
        return getContractAddress(DATA_PROVIDER);
    }

    function setPoolDataProvider(
        address newDataProvider
    ) external override onlyOwner {
        address oldDataProvider = _addresses[DATA_PROVIDER];
        _addresses[DATA_PROVIDER] = newDataProvider;
        emit PoolDataProviderUpdated(oldDataProvider, newDataProvider);
    }

    function _setMarketId(string memory newMarketId) internal {
        string memory oldMarketId = _marketId;
        _marketId = newMarketId;
        emit MarketIdSet(oldMarketId, newMarketId);
    }
}
