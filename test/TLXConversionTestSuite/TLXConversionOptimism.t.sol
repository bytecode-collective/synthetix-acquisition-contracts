// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Bootstrap} from "test/TLXConversionTestSuite/utils/Bootstrap.sol";
import {ITLXConversion} from "src/interfaces/ITLXConversion.sol";

contract TLXConversionTestOptimism is Bootstrap {
    function setUp() public {
        initializeOptimism();
        /// @dev warp ahead of the vesting start time to simulate deployment conditions
        /// (i.e. the contract is deployed after the vesting start time)
        vm.warp(VESTING_START_TIME + 1 weeks);
    }

    function testConversionRateFixed18to1(uint128 amount) public {
        /// @dev this is for setup purposes
        vm.assume(amount <= TLX.balanceOf(LARGEST_TLX_HOLDER));
        vm.assume(amount > 0);
        mintTLX(TEST_USER_1, amount);
        uint256 owedSNXBefore = conversion.owedSNX(TEST_USER_1);
        assertEq(owedSNXBefore, 0);

        vm.startPrank(TEST_USER_1);
        TLX.approve(address(conversion), amount);
        conversion.lockAndConvert();
        vm.stopPrank();

        uint256 owedSNXAfter = conversion.owedSNX(TEST_USER_1);
        uint256 expectedOwedSNX = amount / CONVERSION_RATE;
        assertEq(owedSNXAfter, expectedOwedSNX);
    }

    function testLockAndConvert() public {
        mintTLX(TEST_USER_1, TEST_AMOUNT);
        uint256 owedSNXBefore = conversion.owedSNX(TEST_USER_1);
        uint256 userTLXBefore = TLX.balanceOf(TEST_USER_1);
        uint256 contractTLXBefore = TLX.balanceOf(address(conversion));
        assertEq(owedSNXBefore, 0);
        assertEq(userTLXBefore, TEST_AMOUNT);
        assertEq(contractTLXBefore, 0);

        vm.startPrank(TEST_USER_1);
        TLX.approve(address(conversion), TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();

        uint256 owedSNXAfter = conversion.owedSNX(TEST_USER_1);
        uint256 userTLXAfter = TLX.balanceOf(TEST_USER_1);
        uint256 contractTLXAfter = TLX.balanceOf(address(conversion));
        assertEq(owedSNXAfter, CONVERTED_SNX_AMOUNT);
        assertEq(userTLXAfter, 0);
        assertEq(contractTLXAfter, TEST_AMOUNT);
    }

    function testLockAndConvertAfterVestingDuration() public {
        vm.warp(
            block.timestamp + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
                + 1
        );

        mintTLX(TEST_USER_1, TEST_AMOUNT);
        uint256 owedSNXBefore = conversion.owedSNX(TEST_USER_1);
        uint256 userTLXBefore = TLX.balanceOf(TEST_USER_1);
        uint256 contractTLXBefore = TLX.balanceOf(address(conversion));
        assertEq(owedSNXBefore, 0);
        assertEq(userTLXBefore, TEST_AMOUNT);
        assertEq(contractTLXBefore, 0);

        vm.startPrank(TEST_USER_1);
        TLX.approve(address(conversion), TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();

        uint256 owedSNXAfter = conversion.owedSNX(TEST_USER_1);
        uint256 userTLXAfter = TLX.balanceOf(TEST_USER_1);
        uint256 contractTLXAfter = TLX.balanceOf(address(conversion));
        assertEq(owedSNXAfter, CONVERTED_SNX_AMOUNT);
        assertEq(userTLXAfter, 0);
        assertEq(contractTLXAfter, TEST_AMOUNT);
    }

    function testLockAndConvertEmit() public {
        mintTLX(TEST_USER_1, TEST_AMOUNT);
        vm.startPrank(TEST_USER_1);
        TLX.approve(address(conversion), TEST_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit TLXLocked(TEST_USER_1, TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();
    }

    function testLockAndConvertInsufficientTLX() public {
        uint256 balance = TLX.balanceOf(TEST_USER_2);
        assertEq(balance, 0);

        vm.startPrank(TEST_USER_2);
        TLX.approve(address(conversion), TEST_AMOUNT);
        vm.expectRevert(ITLXConversion.InsufficientTLX.selector);
        conversion.lockAndConvert();
        vm.stopPrank();
    }

    function testVestableAmountBeforeLock() public {
        basicLock();

        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + 1);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertGt(vestableAmount, 0);
    }

    function testVestableAmountLinear() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + 1);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / LINEAR_VESTING_DURATION);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 3
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 3);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
    }

    function testVestableAmountLinearFuzz(uint64 amount) public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(block.timestamp + amount);
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        if (amount > LINEAR_VESTING_DURATION) {
            assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
        } else {
            assertEq(
                vestableAmount,
                CONVERTED_SNX_AMOUNT * amount / LINEAR_VESTING_DURATION
            );
        }
    }

    function testVestableAmountVest() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, (CONVERTED_SNX_AMOUNT / 2) + 1);
    }

    function testVestableAmountLockMore() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        basicLock();
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT * 2);
    }

    function testVestableAmountLockMoreAndVest() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        basicLock();
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT);
    }

    function testVest() public {
        basicLock();

        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        uint256 userSNXFinal = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNX.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT);
        assertEq(contractSNXFinal, MINT_AMOUNT - CONVERTED_SNX_AMOUNT);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT);
    }

    function testVestBasic() public {
        basicLock();

        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXFinal = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNX.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT);
        assertEq(contractSNXFinal, MINT_AMOUNT - CONVERTED_SNX_AMOUNT);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT);
    }

    function testVestExploitVestPartialWaitVestFull() public {
        basicLock();

        vm.warp(VESTING_START_TIME + VESTING_LOCK_DURATION);
        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, CONVERTED_SNX_AMOUNT / 2);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION + LINEAR_VESTING_DURATION
                + LINEAR_VESTING_DURATION / 2
        );

        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, (CONVERTED_SNX_AMOUNT / 2) + 1);

        vm.prank(TEST_USER_1);
        conversion.vest(TEST_USER_1);

        vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);
        assertEq(conversion.claimedSNX(TEST_USER_1), CONVERTED_SNX_AMOUNT);
        assertEq(SNX.balanceOf(TEST_USER_1), CONVERTED_SNX_AMOUNT);
    }

    function testVestBasicThenVestAgainWhenFullyVested() public {
        testVestBasic();
        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        vm.prank(TEST_USER_1);
        vm.expectRevert(ITLXConversion.NoVestableAmount.selector);
        conversion.vest();
        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        assertEq(userSNXAfter, userSNXBefore);

        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);
        assertEq(conversion.claimedSNX(TEST_USER_1), CONVERTED_SNX_AMOUNT);
        assertEq(SNX.balanceOf(TEST_USER_1), CONVERTED_SNX_AMOUNT);
    }

    function testVestBasicThenWaitAndVestAgainWhenFullyVested() public {
        testVestBasic();
        vm.warp(block.timestamp + 30 days);
        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        vm.prank(TEST_USER_1);
        vm.expectRevert(ITLXConversion.NoVestableAmount.selector);
        conversion.vest();
        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        assertEq(userSNXAfter, userSNXBefore);

        uint256 vestableAmount = conversion.vestableAmount(TEST_USER_1);
        assertEq(vestableAmount, 0);
        assertEq(conversion.claimedSNX(TEST_USER_1), CONVERTED_SNX_AMOUNT);
        assertEq(SNX.balanceOf(TEST_USER_1), CONVERTED_SNX_AMOUNT);
    }

    function testVestBasicAndLockAndVestAgain() public {
        testVestBasic();

        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, CONVERTED_SNX_AMOUNT);
        assertEq(contractSNXBefore, MINT_AMOUNT - CONVERTED_SNX_AMOUNT);
        assertEq(claimedSNXBefore, CONVERTED_SNX_AMOUNT);

        /// @dev note that the TLX will be fully vested by this point
        basicLock();
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT * 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT * 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT * 2);
    }

    function testVestAfterWithdraw() public {
        basicLock();

        uint256 userSNXBefore = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 claimedSNXBefore = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXBefore, 0);
        assertEq(contractSNXBefore, MINT_AMOUNT);
        assertEq(claimedSNXBefore, 0);

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        conversion.vest();

        uint256 userSNXAfter = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 claimedSNXAfter = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXAfter, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXAfter, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2));
        assertEq(claimedSNXAfter, CONVERTED_SNX_AMOUNT / 2);

        // withdraw

        uint256 contractSNXBeforeWithdraw = SNX.balanceOf(address(conversion));
        uint256 ownerSNXBeforeWithdraw = SNX.balanceOf(SYNTHETIX_TREASURY);
        assertEq(
            contractSNXBeforeWithdraw, MINT_AMOUNT - (CONVERTED_SNX_AMOUNT / 2)
        );

        vm.warp(VESTING_START_TIME + WITHDRAW_START);
        vm.prank(SYNTHETIX_TREASURY);
        conversion.withdrawSNX();
        vm.prank(TEST_USER_1);
        vm.expectRevert();
        conversion.vest();

        uint256 userSNXFinal = SNX.balanceOf(TEST_USER_1);
        uint256 contractSNXFinal = SNX.balanceOf(address(conversion));
        uint256 claimedSNXFinal = conversion.claimedSNX(TEST_USER_1);
        assertEq(userSNXFinal, CONVERTED_SNX_AMOUNT / 2);
        assertEq(contractSNXFinal, 0);
        assertEq(claimedSNXFinal, CONVERTED_SNX_AMOUNT / 2);

        uint256 contractSNXAfterWithdraw = SNX.balanceOf(address(conversion));
        uint256 ownerSNXAfterWithdraw = SNX.balanceOf(SYNTHETIX_TREASURY);
        assertEq(contractSNXAfterWithdraw, 0);
        assertEq(
            ownerSNXAfterWithdraw,
            ownerSNXBeforeWithdraw + MINT_AMOUNT - CONVERTED_SNX_AMOUNT / 2
        );
    }

    function testVestEmit() public {
        basicLock();

        vm.warp(
            VESTING_START_TIME + VESTING_LOCK_DURATION
                + LINEAR_VESTING_DURATION / 2
        );
        vm.prank(TEST_USER_1);
        vm.expectEmit(true, true, true, true);
        emit SNXVested(TEST_USER_1, TEST_USER_1, CONVERTED_SNX_AMOUNT / 2);
        conversion.vest(TEST_USER_1);
    }

    function testWithdrawSNX() public {
        uint256 contractSNXBefore = SNX.balanceOf(address(conversion));
        uint256 ownerSNXBefore = SNX.balanceOf(SYNTHETIX_TREASURY);
        assertEq(contractSNXBefore, MINT_AMOUNT);

        vm.warp(VESTING_START_TIME + WITHDRAW_START);
        vm.prank(SYNTHETIX_TREASURY);
        conversion.withdrawSNX();

        uint256 contractSNXAfter = SNX.balanceOf(address(conversion));
        uint256 ownerSNXAfter = SNX.balanceOf(SYNTHETIX_TREASURY);
        assertEq(contractSNXAfter, 0);
        assertEq(ownerSNXAfter, ownerSNXBefore + MINT_AMOUNT);
    }

    function testWithdrawSNXOnlyOwner() public {
        vm.prank(TEST_USER_1);
        vm.expectRevert(ITLXConversion.Unauthorized.selector);
        conversion.withdrawSNX();
    }

    function testWithdrawSNXWithdrawalStartTimeNotReached() public {
        vm.warp(VESTING_START_TIME + WITHDRAW_START - 1);
        vm.prank(SYNTHETIX_TREASURY);
        vm.expectRevert(ITLXConversion.WithdrawalStartTimeNotReached.selector);
        conversion.withdrawSNX();

        vm.warp(block.timestamp + 1);
        vm.prank(SYNTHETIX_TREASURY);
        conversion.withdrawSNX();
    }

    function testWithdrawSNXWithdrawalStartTimeNotReachedFuzz(uint128 amount)
        public
    {
        vm.warp(VESTING_START_TIME + amount);
        if (amount < WITHDRAW_START) {
            vm.prank(SYNTHETIX_TREASURY);
            vm.expectRevert(
                ITLXConversion.WithdrawalStartTimeNotReached.selector
            );
            conversion.withdrawSNX();
        } else {
            vm.prank(SYNTHETIX_TREASURY);
            conversion.withdrawSNX();
        }
    }

    function testDeploymentAddressZero() public {
        vm.expectRevert(ITLXConversion.AddressZero.selector);
        bootstrapOptimism.deploySystem(address(0), address(0));
        vm.expectRevert(ITLXConversion.AddressZero.selector);
        bootstrapOptimism.deploySystem(address(TLXMock), address(0));
        vm.expectRevert(ITLXConversion.AddressZero.selector);
        bootstrapOptimism.deploySystem(address(0), address(SNXMock));
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function basicLock() public {
        mintTLX(TEST_USER_1, TEST_AMOUNT);
        vm.startPrank(TEST_USER_1);
        TLX.approve(address(conversion), TEST_AMOUNT);
        conversion.lockAndConvert();
        vm.stopPrank();
    }

    function mintTLX(address user, uint256 amount) public {
        /// @dev this is the TLX treasury
        /// at the current block number it still has TLX
        vm.prank(LARGEST_TLX_HOLDER);
        TLX.transfer(user, amount);
    }
}
