// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

interface TimeLocker {
    error NotPermitted(address sender);
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

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 scheduleTime
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 scheduleTime
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 scheduleTime
    ) external payable returns (bytes memory);
}
