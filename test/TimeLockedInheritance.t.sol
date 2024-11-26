// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "../src/TimeLockedInheritance.sol";


contract TimeLockedInheritanceTest is Test {
    TimeLockedInheritance private inheritanceContract;

    address private depositor = address(1);
    address private beneficiary1 = address(2);
    address private beneficiary2 = address(3);

    function setUp() public {
        inheritanceContract = new TimeLockedInheritance();

        // Fund the depositor address with Ether
        vm.deal(depositor, 10 ether);
    }

    function testDeposit() public {
        vm.startPrank(depositor);

        uint256 depositAmount = 5 ether;
        inheritanceContract.deposit{value: depositAmount}();

        (uint256 balance, , ) = inheritanceContract.getAccountInfo(depositor);
        assertEq(balance, depositAmount, "Balance should match deposit amount");

        vm.stopPrank();
    }

    function testAddBeneficiaries() public {
        vm.startPrank(depositor);

        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = beneficiary1;
        beneficiaries[1] = beneficiary2;

        inheritanceContract.addBeneficiaries(beneficiaries);

        (, , address[] memory storedBeneficiaries) = inheritanceContract.getAccountInfo(depositor);
        assertEq(storedBeneficiaries.length, 2, "There should be two beneficiaries");
        assertEq(storedBeneficiaries[0], beneficiary1, "First beneficiary mismatch");
        assertEq(storedBeneficiaries[1], beneficiary2, "Second beneficiary mismatch");

        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(depositor);

        uint256 depositAmount = 5 ether;
        uint256 withdrawAmount = 2 ether;

        inheritanceContract.deposit{value: depositAmount}();
        uint256 contractBalance = address(inheritanceContract).balance;
        assert(contractBalance >= withdrawAmount);

        inheritanceContract.withdraw(withdrawAmount);

        (uint256 balance, , ) = inheritanceContract.getAccountInfo(depositor);
        assertEq(balance, depositAmount - withdrawAmount, "Balance mismatch after withdrawal");
        assertEq(depositor.balance, withdrawAmount, "Withdrawn amount not credited to depositor");

        vm.stopPrank();
    }

    function testWithdrawExceedingBalance() public {
        vm.startPrank(depositor); 

        uint256 depositAmount = 5 ether;
        uint256 withdrawAmount = 6 ether; // Exceeds balance, should revert

        inheritanceContract.deposit{value: depositAmount}();

        // Expect a revert due to insufficient balance
        vm.expectRevert("Insufficient balance");
        inheritanceContract.withdraw(withdrawAmount);

        vm.stopPrank();
    }

    function testWithdrawAsBeneficiaryAfterInactivity() public {
        vm.startPrank(depositor);

        uint256 depositAmount = 5 ether;
        inheritanceContract.deposit{value: depositAmount}();

        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = beneficiary1;
        inheritanceContract.addBeneficiaries(beneficiaries);

        vm.stopPrank();

        // Simulate inactivity period
        vm.warp(block.timestamp + 1825 days);

        vm.startPrank(beneficiary1);
        inheritanceContract.withdrawAsBeneficiary(depositor);

        (uint256 balance, , ) = inheritanceContract.getAccountInfo(depositor);
        assertEq(balance, 0, "Balance should be zero after beneficiary withdrawal");
        assertEq(beneficiary1.balance, depositAmount, "Withdrawn amount not credited to beneficiary");

        vm.stopPrank();
    }

    function testCannotWithdrawAsBeneficiaryBeforeInactivity() public {
        vm.startPrank(depositor);

        uint256 depositAmount = 5 ether;
        inheritanceContract.deposit{value: depositAmount}();

        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = beneficiary1;
        inheritanceContract.addBeneficiaries(beneficiaries);

        vm.stopPrank();

        vm.startPrank(beneficiary1);
        vm.expectRevert("Benefactor is still active");
        inheritanceContract.withdrawAsBeneficiary(depositor);

        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanBalance() public {
        vm.startPrank(depositor);

        uint256 depositAmount = 5 ether;
        inheritanceContract.deposit{value: depositAmount}();

        uint256 withdrawAmount = 10 ether; // Exceeds balance
        vm.expectRevert("Insufficient balance");
        inheritanceContract.withdraw(withdrawAmount);

        vm.stopPrank();
    }
}
