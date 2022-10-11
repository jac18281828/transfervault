// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

import "../contracts/Constant.sol";
import "../contracts/TimeLock.sol";
import "../contracts/Vault.sol";

contract TransferVault is Vault {
    TimeLock private immutable _timeLock;
    ERC20PresetMinterPauser public immutable _transferToken;

    uint256 public totalSupply;
    mapping(address => uint256) private _balanceOf;
    mapping(address => uint256) private _paymentFor;
    mapping(address => uint256) private _scheduleTime;

    constructor() {
        _timeLock = new TimeLock(Constant.MINIMUM_DELAY);
        _transferToken = new ERC20PresetMinterPauser(
            "VaultXTransferToken",
            "VTT20"
        );
    }

    receive() external payable {
        revert FallbackNotPermitted();
    }

    fallback() external payable {
        pay(msg.sender, balance(msg.sender));
    }

    function deposit() external payable {
        uint256 _amount = msg.value;
        if (_amount == 0) revert NoShares();
        _mint(msg.sender, _amount);
        emit Deposit(_amount);
    }

    function withdraw(uint256 _shares) external {
        approve(msg.sender, balance(msg.sender), _shares);
    }

    function approve(address _to) public {
        uint256 toBalance = balance(_to);
        uint256 toShares = shares(_to);
        if (toBalance == 0 && toShares == 0) {
            revert InsufficientShares(toShares, toShares);
        }
        approve(_to, toBalance, toShares);
    }

    function approve(
        address _to,
        uint256 _balance,
        uint256 _shares
    ) public {
        uint256 availableQty = balance(_to);
        if (availableQty < _balance) {
            revert InsufficientBalance(_balance, availableQty);
        }
        if (_scheduleTime[_to] > 0) {
            revert TransactionInProgress(msg.sender);
        }
        if (_shares > 0) {
            _transferToken.transferFrom(msg.sender, address(this), _shares);
            _burn(msg.sender, _to, _shares);
        }
        uint256 amountClaimed = _balance + _shares;
        uint256 scheduleTime = getBlockTimestamp() + Constant.MINIMUM_DELAY;
        _scheduleTime[_to] = scheduleTime;
        _timeLock.queueTransaction(_to, amountClaimed, "", "", scheduleTime);
        emit Withdraw(amountClaimed, _to, scheduleTime);
    }

    function pay(uint256 _amount) public {
        pay(msg.sender, _amount);
    }

    function pay(address _to, uint256 _amount) public {
        if (_paymentFor[_to] == 0 || _paymentFor[_to] < _amount) {
            revert InsufficientBalance(_paymentFor[_to], _amount);
        }
        uint256 scheduleTime = _scheduleTime[_to];
        clearSchedule(_to);
        _paymentFor[_to] -= _amount;
        _timeLock.executeTransaction(_to, _amount, "", "", scheduleTime);
        emit Payment(_amount, _to);
    }

    function cancel(uint256 _amount) external {
        cancel(msg.sender, _amount);
    }

    function cancel(address _to, uint256 _amount) public {
        if (_scheduleTime[_to] == 0) {
            revert NotPending(_to);
        }
        _timeLock.cancelTransaction(_to, _amount, "", "", _scheduleTime[_to]);
        clearSchedule(_to);
    }

    function shares(address _from) public view returns (uint256) {
        return _transferToken.balanceOf(_from);
    }

    function balance(address _from) public view returns (uint256) {
        return _paymentFor[_from];
    }

    function clearSchedule(address _to) private {
        _scheduleTime[_to] = 0;
        delete _scheduleTime[_to];
    }

    function _burn(
        address _from,
        address _to,
        uint256 _shares
    ) private {
        totalSupply -= _shares;
        _balanceOf[_from] -= _shares;
        _transferToken.burn(_shares);
        _paymentFor[_to] += _shares;
        payable(_timeLock).transfer(_shares);
    }

    function _mint(address _to, uint256 _shares) private {
        totalSupply += _shares;
        _balanceOf[_to] += _shares;
        _transferToken.mint(_to, _shares);
    }

    function getBlockTimestamp() private view returns (uint256) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp;
    }
}
