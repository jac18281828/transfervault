// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../contracts/Constant.sol";
import "../contracts/TimeLocker.sol";

// modified version of
// https://github.com/compound-finance/compound-protocol/blob/a3214f67b73310d547e00fc578e8355911c9d376/contracts/Timelock.sol
contract TimeLock is Ownable, TimeLocker {
    uint256 public immutable _lockTime;

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

    fallback() external {
        revert NotPermitted(msg.sender);
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
        bytes32 txHash = getTxHash(
            target,
            value,
            signature,
            data,
            scheduleTime
        );
        if (!_queuedTransaction[txHash]) revert NotInQueue(txHash);
        uint256 blockTime = getBlockTimestamp();
        if (blockTime < scheduleTime) revert TransactionLocked(txHash);
        if (blockTime > (scheduleTime + Constant.GRACE_PERIOD))
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

        // solhint-disable-next-line avoid-low-level-calls
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
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }

    function clearQueued(bytes32 txHash) private {
        // overwrite memory to protect against value rebinding
        _queuedTransaction[txHash] = false;
        delete _queuedTransaction[txHash];
    }
}
