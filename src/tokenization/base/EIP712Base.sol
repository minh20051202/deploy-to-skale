// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

abstract contract EIP712Base {
    bytes public constant EIP712_REVISION = bytes("1");
    bytes32 internal constant EIP712_DOMAIN =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    mapping(address => uint256) _nonces;

    bytes32 internal _domainSeparator;
    uint256 internal immutable _chainId;

    constructor() {
        _chainId = block.chainid;
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        if (block.chainid == _chainId) {
            return _domainSeparator;
        }
        return _calculateDomainSeparator();
    }

    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    function _calculateDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN,
                    keccak256(bytes(_EIP712BaseId())),
                    keccak256(EIP712_REVISION),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _EIP712BaseId() internal view virtual returns (string memory);
}
