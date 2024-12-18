// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.25;

/// @title Contract for defining constants used in testing
contract Constants {
    address internal constant SYNTHETIX_TREASURY =
        0xD25215758734dd3aDE497CE04De1c35820964126;
    /// @dev this is for testing setup purposes
    address public constant LARGEST_SNX_HOLDER =
        0xa5f7a39E55D7878bC5bd754eE5d6BD7a7662355b;
    address internal constant LARGEST_TLX_HOLDER =
        0x000000000000000000000000000000000000dEaD;
    address internal constant TEST_USER_1 = address(0x2);
    address internal constant TEST_USER_2 = address(0x3);
    uint256 internal constant TEST_AMOUNT = 1000 * 10 ** 18;
    uint256 internal constant CONVERSION_RATE = 18;
    uint256 internal constant CONVERTED_SNX_AMOUNT =
        TEST_AMOUNT / CONVERSION_RATE;
    uint256 internal constant VESTING_LOCK_DURATION = 30 days;
    uint256 internal constant VESTING_START_TIME = 1_733_356_800;
    uint256 internal constant WITHDRAW_START = 730 days;
    uint256 internal constant LINEAR_VESTING_DURATION = 120 days;
    uint256 internal constant MINT_AMOUNT = 1_000_000 * 10 ** 18;
    // BLOCK_NUMBER corresponds to Dec-18-2024 01:14:01 AM +UTC
    uint256 internal constant OPTIMISM_BLOCK_NUMBER = 129_442_832;
}
