// SPDX-License-Identifier: BSD-3-Clause
// solhint-disable not-rely-on-time
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import "../contracts/Constant.sol";
import "../contracts/TransferVault.sol";
import "../contracts/TimeLock.sol";

contract TransferVaultTest is Test {
    TransferVault private _transferVault;
    TimeLock private _timeLock;

    address private constant _OWNER = address(0x10);
    address private constant _SPENDER = address(0x11);

    uint256 private constant _DEPOSIT = 10 wei;

    function setUp() public {
        vm.clearMockedCalls();
        _timeLock = new TimeLock(Constant.MINIMUM_DELAY);
        _transferVault = new TransferVault();
        _timeLock.transferOwnership(_OWNER);
    }

    function testInitialDeposit() public {
        sendMoneySoon();
        assertEq(_transferVault._transferToken().balanceOf(_OWNER), _DEPOSIT);
        assertEq(address(_transferVault).balance, _DEPOSIT);
        assertEq(_transferVault.totalSupply(), _DEPOSIT);
    }

    function testWithdrawShares() public {
        sendMoneySoon();
        vm.startPrank(_OWNER);
        _transferVault._transferToken().approve(
            address(_transferVault),
            _DEPOSIT
        );
        _transferVault.withdraw(_DEPOSIT);
        vm.stopPrank();
        assertEq(_transferVault.balance(_OWNER), _DEPOSIT);
    }

    function testWithdrawSteps() public {
        sendMoneySoon();
        vm.startPrank(_OWNER);
        _transferVault._transferToken().approve(
            address(_transferVault),
            _DEPOSIT
        );
        uint256 _step = _DEPOSIT / 10;
        for (uint256 i = 0; i < _DEPOSIT; i += _step) {
            _transferVault.withdraw(_step);
            assertEq(_transferVault.balance(_OWNER), _step);
            vm.warp(block.timestamp + Constant.MINIMUM_DELAY);
            _transferVault.pay(_step);
            assertEq(_OWNER.balance, (i + 1) * _step);
        }
        vm.stopPrank();
        assertEq(_transferVault.balance(_OWNER), 0);
        assertEq(_OWNER.balance, _DEPOSIT);
    }

    function testWithdrawAndMoveMoney() public {
        sendMoneySoon();
        vm.startPrank(_OWNER);
        _transferVault._transferToken().approve(
            address(_transferVault),
            _DEPOSIT
        );
        _transferVault.withdraw(_DEPOSIT);
        vm.warp(block.timestamp + Constant.MINIMUM_DELAY);
        _transferVault.pay(_DEPOSIT);
        vm.stopPrank();
        assertEq(_transferVault.balance(_OWNER), 0);
        assertEq(_OWNER.balance, _DEPOSIT);
    }

    function testWithdrawAndPaySpender() public {
        sendMoneySoon();
        vm.startPrank(_OWNER);
        _transferVault._transferToken().approve(
            address(_transferVault),
            _DEPOSIT
        );
        _transferVault.authorize(_SPENDER, _DEPOSIT);
        assertEq(_transferVault.balance(_SPENDER), _DEPOSIT);
        vm.warp(block.timestamp + Constant.MINIMUM_DELAY);
        _transferVault.pay(_SPENDER, _DEPOSIT);
        vm.stopPrank();
        assertEq(_transferVault.balance(_SPENDER), 0);
        assertEq(_SPENDER.balance, _DEPOSIT);
    }

    function testFallbackFunctionNotAllowed() public {
        sendMoneySoon();
        vm.startPrank(_OWNER);
        _transferVault._transferToken().approve(
            address(_transferVault),
            _DEPOSIT
        );
        _transferVault.withdraw(_DEPOSIT);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = address(_transferVault).call{
            value: _DEPOSIT
        }("");
        vm.stopPrank();
        assertFalse(success);
        emit log_bytes(returnData);
    }

    function testFailNoBalance() public {
        vm.startPrank(_OWNER);
        _transferVault._transferToken().approve(
            address(_transferVault),
            _DEPOSIT
        );
        _transferVault.withdraw(_DEPOSIT);
        vm.stopPrank();
    }

    function testFailDepositRequired() public {
        vm.deal(_OWNER, _DEPOSIT);
        vm.prank(_OWNER);
        payable(_transferVault).transfer(_DEPOSIT);
    }

    function sendMoneySoon() private {
        vm.deal(_OWNER, _DEPOSIT);
        bytes memory depositData = abi.encodeWithSelector(
            _transferVault.deposit.selector
        );
        vm.startPrank(_OWNER);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returnData) = payable(_transferVault).call{
            value: _DEPOSIT
        }(depositData);
        vm.stopPrank();
        assertTrue(success);
        emit log_bytes(returnData);
    }
}
