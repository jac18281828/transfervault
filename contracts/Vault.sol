// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.15;

interface Vault {
    error FallbackNotPermitted();
    error NoShares();
    error TransactionInProgress(address sender);
    error NotPending(address payee);

    error InsufficientShares(uint256 requested, uint256 available);
    error InsufficientBalance(uint256 requested, uint256 available);

    event Deposit(uint256 shares);
    event Withdraw(uint256 shares, address _to, uint256 timeAvailable);
    event Payment(uint256 amount, address _to);

    function deposit() external payable;

    function withdraw(uint256 _shares) external;

    function approve(address _to) external;

    function approve(
        address _to,
        uint256 _balance,
        uint256 _shares
    ) external;

    function pay(uint256 _amount) external;

    function pay(address _to, uint256 _amount) external;

    function cancel(uint256 _amount) external;

    function cancel(address _to, uint256 _amount) external;

    function balance(address _from) external view returns (uint256);
}
