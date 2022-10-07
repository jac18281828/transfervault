// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

import "../contracts/Constant.sol";
import "../contracts/TimeLock.sol";

contract TransferVault {
    event Deposit(uint256 shares);
    event Withdraw(uint256 shares, address _to);
    event Payment(uint256 amount, address _to);
    TimeLock private immutable _timeLock;
    ERC20PresetMinterPauser public immutable _transferToken;

    uint256 public totalSupply;
    mapping(address => uint256) private _balanceOf;
    mapping(address => uint256) private _paymentFor;
    mapping(address => uint256) private _scheduleTime;

    constructor() {
        _timeLock = new TimeLock(Constant.MINIMUM_DELAY);
        _transferToken = new ERC20PresetMinterPauser(
            "VaultxTransferToken",
            "VTT20"
        );
    }

    event log_uint256(uint256 _amount);

    receive() external payable {
        revert("Must deposit");
    }

    fallback() external payable {
        revert("Must pay");
    }

    function deposit() external payable {
        uint256 _amount = msg.value;
        require(_amount > 0, "No shares");
        _mint(msg.sender, _amount);
        emit Deposit(_amount);
    }

    function withdraw(uint256 _shares) external {
        require(
            _balanceOf[msg.sender] >= _shares,
            "Insufficient shares available"
        );
        require(_scheduleTime[msg.sender] == 0, "Transaction in process");
        _transferToken.transferFrom(msg.sender, address(this), _shares);
        _burn(msg.sender, msg.sender, _shares);
        emit Withdraw(_shares, msg.sender);
    }

    function authorize(address _to, uint256 _shares) external {
        require(
            _balanceOf[msg.sender] >= _shares,
            "Insufficient shares available"
        );
        require(_scheduleTime[_to] == 0, "Transaction in process");
        _transferToken.transferFrom(msg.sender, address(this), _shares);
        _burn(msg.sender, _to, _shares);
        emit Withdraw(_shares, _to);
    }

    function pay(uint256 _amount) public {
        pay(msg.sender, _amount);
    }

    function pay(address _to, uint256 _amount) public {
        require(_paymentFor[_to] >= _amount, "Insufficient funds");
        _timeLock.executeTransaction(_to, _amount, "", "", _scheduleTime[_to]);
        _scheduleTime[_to] = 0;
        delete _scheduleTime[_to];
        _paymentFor[_to] -= _amount;
        emit Payment(_amount, _to);
    }

    function balance(address _from) external view returns (uint256) {
        return _paymentFor[_from];
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
        _scheduleTime[_to] = block.timestamp + Constant.MINIMUM_DELAY;
        payable(_timeLock).transfer(_shares);
        _timeLock.queueTransaction(_to, _shares, "", "", _scheduleTime[_to]);
    }

    function _mint(address _to, uint256 _shares) private {
        totalSupply += _shares;
        _balanceOf[_to] += _shares;
        _transferToken.mint(_to, _shares);
    }
}
