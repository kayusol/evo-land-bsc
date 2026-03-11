// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SettingsRegistry
 * @dev Central registry for all contract addresses and configuration values.
 */
contract SettingsRegistry is Ownable {

    mapping(bytes32 => uint256) public uintOf;
    mapping(bytes32 => address) public addressOf;
    mapping(bytes32 => bytes32) public bytesOf;
    mapping(bytes32 => bool)    public boolOf;
    mapping(bytes32 => int256)  public intOf;
    mapping(bytes32 => string)  public stringOf;

    event UpdateUint(bytes32 indexed _key, uint256 _value);
    event UpdateAddress(bytes32 indexed _key, address _value);
    event UpdateBytes(bytes32 indexed _key, bytes32 _value);
    event UpdateBool(bytes32 indexed _key, bool _value);
    event UpdateInt(bytes32 indexed _key, int256 _value);
    event UpdateString(bytes32 indexed _key, string _value);

    constructor() Ownable(msg.sender) {}

    function setUintProperty(bytes32 _key, uint256 _value) external onlyOwner {
        uintOf[_key] = _value;
        emit UpdateUint(_key, _value);
    }

    function setAddressProperty(bytes32 _key, address _value) external onlyOwner {
        addressOf[_key] = _value;
        emit UpdateAddress(_key, _value);
    }

    function setBytesProperty(bytes32 _key, bytes32 _value) external onlyOwner {
        bytesOf[_key] = _value;
        emit UpdateBytes(_key, _value);
    }

    function setBoolProperty(bytes32 _key, bool _value) external onlyOwner {
        boolOf[_key] = _value;
        emit UpdateBool(_key, _value);
    }

    function setIntProperty(bytes32 _key, int256 _value) external onlyOwner {
        intOf[_key] = _value;
        emit UpdateInt(_key, _value);
    }

    function setStringProperty(bytes32 _key, string calldata _value) external onlyOwner {
        stringOf[_key] = _value;
        emit UpdateString(_key, _value);
    }
}
