// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../contracts/TimeLock.sol";

contract TimeLockTest is Test {
    uint256 private constant _WEEK_DELAY = 7 days;
    address private constant _FUNCTION = address(0x7);
    address private constant _NOT_OWNER = address(0xffee);
    address private constant _TYCOON = address(0x1001);
    address private constant _JOE = address(0x1002);
    // solhint-disable-next-line var-name-mixedcase
    address private immutable _OWNER = address(0xffdd);

    TimeLock private _timeLock;

    function setUp() public {
        vm.clearMockedCalls();
        _timeLock = new TimeLock(_WEEK_DELAY);
        _timeLock.transferOwnership(_OWNER);
    }

    function testMinimumRequiredDelay(uint256 delayDelta) public {
        vm.assume(delayDelta > 0 && delayDelta < Constant.MINIMUM_DELAY);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.RequiredDelayNotInRange.selector,
                Constant.MINIMUM_DELAY - delayDelta,
                Constant.MINIMUM_DELAY,
                Constant.MAXIMUM_DELAY
            )
        );
        new TimeLock(Constant.MINIMUM_DELAY - delayDelta);
    }

    function testMaximumRequiredDelay(uint256 delayDelta) public {
        vm.assume(
            delayDelta > Constant.MAXIMUM_DELAY &&
                delayDelta < Constant.UINT_MAX - Constant.MAXIMUM_DELAY
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.RequiredDelayNotInRange.selector,
                Constant.MAXIMUM_DELAY + delayDelta,
                Constant.MINIMUM_DELAY,
                Constant.MAXIMUM_DELAY
            )
        );
        new TimeLock(Constant.MAXIMUM_DELAY + delayDelta);
    }

    function testTransactionEarlyForTimeLock(uint256 timeDelta) public {
        vm.assume(timeDelta > 1 && timeDelta < _WEEK_DELAY);
        bytes32 txHash = _timeLock.getTxHash(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY - timeDelta
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.TimestampNotInRange.selector,
                txHash,
                block.timestamp,
                block.timestamp + _WEEK_DELAY - timeDelta
            )
        );
        vm.prank(_OWNER);
        _timeLock.queueTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY - timeDelta
        );
    }

    function testTransactionLateForTimeLock(uint256 timeDelta) public {
        vm.assume(
            timeDelta > 0 &&
                timeDelta <
                (Constant.UINT_MAX - _WEEK_DELAY - Constant.GRACE_PERIOD)
        );
        bytes32 txHash = _timeLock.getTxHash(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY + Constant.GRACE_PERIOD + timeDelta
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.TimestampNotInRange.selector,
                txHash,
                block.timestamp,
                block.timestamp +
                    _WEEK_DELAY +
                    Constant.GRACE_PERIOD +
                    timeDelta
            )
        );

        vm.prank(_OWNER);
        _timeLock.queueTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY + Constant.GRACE_PERIOD + timeDelta
        );
    }

    function testOwnerMustQueueTransaction() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_NOT_OWNER);
        _timeLock.queueTransaction(
            address(100),
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
    }

    function testQueueTransactionHash() public {
        vm.prank(_OWNER);
        bytes32 hashValue = _timeLock.queueTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
        assertTrue(_timeLock._queuedTransaction(hashValue));
        assertEq(
            hashValue,
            0xfb5a0fa7bd3bcd62232b1089ddbf45e63aa6d00e6cdf09f48ce3bb8d034746a2
        );
    }

    function testQueueTransactionDoubleQueue() public {
        vm.prank(_OWNER);
        bytes32 hashValue = _timeLock.queueTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
        assertTrue(_timeLock._queuedTransaction(hashValue));
        vm.expectRevert(
            abi.encodeWithSelector(
                TimeLocker.AlreadyInQueue.selector,
                hashValue
            )
        );
        vm.prank(_OWNER);
        _timeLock.queueTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
    }

    function testCancelTransaction() public {
        vm.prank(_OWNER);
        bytes32 hashValue = _timeLock.queueTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
        assertTrue(_timeLock._queuedTransaction(hashValue));
        vm.prank(_OWNER);
        _timeLock.cancelTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
        assertFalse(_timeLock._queuedTransaction(hashValue));
    }

    function testCancelTransactionRequiresOwner() public {
        vm.prank(_OWNER);
        bytes32 hashValue = _timeLock.queueTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
        assertTrue(_timeLock._queuedTransaction(hashValue));
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(_NOT_OWNER);
        _timeLock.cancelTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
    }

    function testExecuteRequiresOwner() public {
        vm.prank(_OWNER);
        _timeLock.queueTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
        vm.expectRevert("Ownable: caller is not the owner");
        vm.warp(block.timestamp + _WEEK_DELAY);
        vm.prank(_NOT_OWNER);
        _timeLock.executeTransaction(
            _FUNCTION,
            7,
            "abc",
            "data",
            block.timestamp + _WEEK_DELAY
        );
    }

    function testExecuteTransaction(uint256 systemClock) public {
        vm.assume(
            systemClock < Constant.UINT_MAX - _WEEK_DELAY - block.timestamp
        );
        vm.warp(block.timestamp + systemClock);
        FlagSet flag = new FlagSet();
        address flagMock = address(flag);
        bytes memory data = abi.encodeWithSelector(flag.set.selector);
        uint256 scheduleTime = block.timestamp + _WEEK_DELAY;
        vm.prank(_OWNER);
        bytes32 hashValue = _timeLock.queueTransaction(
            flagMock,
            0,
            "",
            data,
            scheduleTime
        );
        assertTrue(_timeLock._queuedTransaction(hashValue));
        vm.warp(block.timestamp + _WEEK_DELAY);
        vm.prank(_OWNER);
        _timeLock.executeTransaction(flagMock, 0, "", data, scheduleTime);
        assertFalse(_timeLock._queuedTransaction(hashValue));
        assertTrue(flag.isSet());
    }

    function testKingMaker() public {
        vm.deal(_TYCOON, 10 wei);
        vm.prank(_TYCOON);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory _ignore) = _JOE.call{value: 1 wei}("");
        emit log_bytes(_ignore);
        assertTrue(success);
        assertEq(_JOE.balance, 1 wei);
        assertEq(_TYCOON.balance, 9 wei);
    }

    function testTransferCoin() public {
        vm.deal(_TYCOON, 10 wei);
        vm.prank(_TYCOON);
        payable(_timeLock).transfer(10 wei);
        assertEq(_TYCOON.balance, 0);
        uint256 scheduleTime = block.timestamp + _WEEK_DELAY;
        vm.prank(_OWNER);
        _timeLock.queueTransaction(_JOE, 10 wei, "", "", scheduleTime);
        vm.warp(scheduleTime);
        vm.prank(_OWNER);
        _timeLock.executeTransaction(_JOE, 10 wei, "", "", scheduleTime);
        assertEq(_JOE.balance, 10 wei);
    }

    function testFallbackNotAllowed() public {
        vm.deal(_JOE, 1 ether);
        vm.prank(_JOE);
        payable(_timeLock).transfer(1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(TimeLocker.NotPermitted.selector, _JOE)
        );
        vm.prank(_JOE);
        (bool ok, bytes memory retData) = address(_timeLock).call("fallback()");
        // unreachable but solc still warns without it
        assertTrue(ok);
        emit log_bytes(retData);
    }
}

contract FlagSet {
    bool public isSet = false;

    function set() external {
        isSet = true;
    }
}
