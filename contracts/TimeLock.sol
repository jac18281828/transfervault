// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../contracts/Constant.sol";

// based on https://github.com/compound-finance/compound-protocol/blob/a3214f67b73310d547e00fc578e8355911c9d376/contracts/Timelock.sol

contract TimeLock is Ownable {
    error AlreadyInQueue(bytes32 txHash);
    error TimestampNotInRange(
        bytes32 txHash,
        uint256 timestamp,
        uint256 scheduleTime
    );
    error RequiredDelayNotInRange(
        uint256 lockDelay,
        uint256 minDelay,
        uint256 maxDelay
    );
    error NotInQueue(bytes32 txHash);
    error TransactionLocked(bytes32 txHash);
    error TransactionStale(bytes32 txHash);
    error ExecutionFailed(bytes32 txHash);

    event ReceiveEth(address sender, uint256 amount);
    event SendEth(address recipient, uint256 amount);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 scheduleTime
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 scheduleTime
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 scheduleTime
    );

    uint256 public _lockTime;

    mapping(bytes32 => bool) public _queuedTransaction;

    constructor(uint256 _lockDelay) {
        if (
            _lockDelay < Constant.MINIMUM_DELAY ||
            _lockDelay > Constant.MAXIMUM_DELAY
        ) {
            revert RequiredDelayNotInRange(
                _lockDelay,
                Constant.MINIMUM_DELAY,
                Constant.MAXIMUM_DELAY
            );
        }
        _lockTime = _lockDelay;
    }

    receive() external payable {
        emit ReceiveEth(msg.sender, msg.value);
    }

    fallback() external payable {
        emit SendEth(msg.sender, msg.value);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 scheduleTime
    ) external onlyOwner returns (bytes32) {
        bytes32 txHash = getTxHash(
            target,
            value,
            signature,
            data,
            scheduleTime
        );

        uint256 blockTime = getBlockTimestamp();
        if (
            scheduleTime < (blockTime + _lockTime) ||
            scheduleTime > (blockTime + _lockTime + Constant.GRACE_PERIOD)
        ) {
            revert TimestampNotInRange(txHash, blockTime, scheduleTime);
        }

        if (_queuedTransaction[txHash]) {
            revert AlreadyInQueue(txHash);
        }
        _queuedTransaction[txHash] = true;

        emit QueueTransaction(
            txHash,
            target,
            value,
            signature,
            data,
            scheduleTime
        );
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 scheduleTime
    ) external onlyOwner {
        bytes32 txHash = getTxHash(
            target,
            value,
            signature,
            data,
            scheduleTime
        );
        if (!_queuedTransaction[txHash]) revert NotInQueue(txHash);
        clearQueued(txHash);

        emit CancelTransaction(
            txHash,
            target,
            value,
            signature,
            data,
            scheduleTime
        );
    }

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 scheduleTime
    ) external payable onlyOwner returns (bytes memory) {
        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, scheduleTime)
        );
        if (!_queuedTransaction[txHash]) revert NotInQueue(txHash);
        uint256 blockTime = getBlockTimestamp();
        if (blockTime < scheduleTime) revert TransactionLocked(txHash);
        if (blockTime > (_lockTime + Constant.GRACE_PERIOD))
            revert TransactionStale(txHash);
        clearQueued(txHash);

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }

        // solhint-disable-next-line security/no-call-value
        (bool ok, bytes memory returnData) = target.call{value: value}(
            callData
        );
        if (!ok) revert ExecutionFailed(txHash);

        emit ExecuteTransaction(
            txHash,
            target,
            value,
            signature,
            data,
            scheduleTime
        );

        return returnData;
    }

    function getTxHash(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 scheduleTime
    ) public pure returns (bytes32) {
        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, scheduleTime)
        );
        return txHash;
    }

    function getBlockTimestamp() private view returns (uint256) {
        return block.timestamp;
    }

    function clearQueued(bytes32 txHash) private {
        // overwrite memory to protect against value rebinding
        _queuedTransaction[txHash] = false;
        delete _queuedTransaction[txHash];
    }
}
