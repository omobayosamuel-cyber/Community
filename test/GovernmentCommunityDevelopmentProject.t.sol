// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {GovernmentCommunityDevelopmentProject} from "../src/GovernmentCommunityDevelopmentProject.sol";
import {Test, console} from "../lib/forge-std/src/Test.sol";

contract GovernmentCommunityDevelopmentProjectTest is Test {
    GovernmentCommunityDevelopmentProject public communityProject;

    // Accounts for testing
    address public governmentAdmin = address(this);
    address public nonAdmin = 0xF9cFa386b3EE113812f459525D62DcF7d93E9fC1;
    address public contractor = 0xa8e513f5E273eb107Cafa75419b70f35738252DF;
    address public newAdmin = 0x497226c9E38d11eaF3873C428daB383d21CBAc55;

    function setUp() public {
        communityProject = new GovernmentCommunityDevelopmentProject();
        
        // Fund nonAdmin and contractor with test ETH
        vm.deal(nonAdmin,  36 ether);
        vm.deal(contractor,  36 ether);
    }

    // ==========================================
    // 1. DEPOSIT TESTS
    // ==========================================

    function test_DepositGovernmentFunds_Success() public {
        uint256 depositAmount = 18 ether; // Proportional half-split of 36 ether

        vm.expectEmit(true, false, false, true);
        emit GovernmentCommunityDevelopmentProject.GovernmentFundsDeposited(address(this), depositAmount);
        
        communityProject.depositGovernmentFunds{value: depositAmount}();

        assertEq(communityProject.getTreasuryBalance(), depositAmount);
        assertEq(communityProject.totalGovernmentFunding(), depositAmount);
    }

    function test_RevertWhen_DepositZeroETH() public {
        vm.expectRevert(GovernmentCommunityDevelopmentProject.MustSendETHToFundProjects.selector);
        communityProject.depositGovernmentFunds{value: 0}();
    }

    function test_RevertWhen_NonAdminDeposits() public {
        vm.prank(nonAdmin);
        vm.expectRevert(GovernmentCommunityDevelopmentProject.OnlyGovernmentAdminCanPerformThisAction.selector);
        communityProject.depositGovernmentFunds{value: 1 ether}();
    }

    // ==========================================
    // 2. CREATE PROJECT TESTS
    // ==========================================
    function test_CreateProject_Success() public {
        string memory name = "Lagos Central";
        GovernmentCommunityDevelopmentProject.ProjectType pType = GovernmentCommunityDevelopmentProject.ProjectType.Road;
        string memory desc = "Paving main road";
        uint256 budget = 36 ether; // Scaled to 36 ether

        vm.expectEmit(true, false, false, true);
        emit GovernmentCommunityDevelopmentProject.ProjectCreated(1, name, pType, budget);
        
        communityProject.createProject(name, pType, desc, budget);

        assertEq(communityProject.projectCount(), 1);
        (
            uint256 id,
            string memory pName,
            GovernmentCommunityDevelopmentProject.ProjectType retType,
            string memory pDesc,
            uint256 totalBudget,
            uint256 fundsAllocated,
            GovernmentCommunityDevelopmentProject.ProjectStatus status,
            address assignedContractor
        ) = communityProject.projects(1);

        assertEq(id, 1);
        assertEq(pName, name);
        assertTrue(retType == pType);
        assertEq(pDesc, desc);
        assertEq(totalBudget, budget);
        assertEq(fundsAllocated, 0);
        assertTrue(status == GovernmentCommunityDevelopmentProject.ProjectStatus.Proposed);
        assertEq(assignedContractor, address(0));
    }

    function test_RevertWhen_CreateProjectZeroBudget() public {
        vm.expectRevert(GovernmentCommunityDevelopmentProject.totalBudgetMustBeGreaterThan0.selector);
        communityProject.createProject("Ward A", GovernmentCommunityDevelopmentProject.ProjectType.Drainage, "Drainage work", 0);
    }

    // ==========================================
    // 3. APPROVE PROJECT TESTS
    // ==========================================
    function test_ApproveProject_Success() public {
        communityProject.createProject("Ward B", GovernmentCommunityDevelopmentProject.ProjectType.Drainage, "Drainage work", 18 ether);
        
        vm.expectEmit(true, false, false, true);
        emit GovernmentCommunityDevelopmentProject.ProjectApproved(1);
        
        communityProject.approveProject(1);

        (, , , , , , GovernmentCommunityDevelopmentProject.ProjectStatus status, ) = communityProject.projects(1);
        assertTrue(status == GovernmentCommunityDevelopmentProject.ProjectStatus.Approved);
    }

    function test_RevertWhen_ApproveNonExistentProject() public {
        vm.expectRevert(GovernmentCommunityDevelopmentProject.ProjectDoesNotExist.selector);
        communityProject.approveProject(99);
    }

    // ==========================================
    // 4. ASSIGN CONTRACTOR TESTS
    // ==========================================
    function test_AssignContractor_Success() public {
        communityProject.createProject("Ward C", GovernmentCommunityDevelopmentProject.ProjectType.BoleHole, "Clean water", 6 ether);
        communityProject.approveProject(1);

        vm.expectEmit(true, false, false, true);
        emit GovernmentCommunityDevelopmentProject.ContractorAssigned(1, contractor);
        
        communityProject.assignContractor(1, contractor);

        (, , , , , , GovernmentCommunityDevelopmentProject.ProjectStatus status, address assignedContractor) = communityProject.projects(1);
        assertTrue(status == GovernmentCommunityDevelopmentProject.ProjectStatus.InProgress);
        assertEq(assignedContractor, contractor);
    }

    function test_RevertWhen_AssignContractorToUnapprovedProject() public {
        communityProject.createProject("Ward D", GovernmentCommunityDevelopmentProject.ProjectType.Road, "Road work", 6 ether);
        vm.expectRevert(GovernmentCommunityDevelopmentProject.ProjectMustBeApprovedBeforeAssigningAContractor.selector);
        communityProject.assignContractor(1, contractor);
    }

    function test_RevertWhen_AssignZeroAddressContractor() public {
        communityProject.createProject("Ward E", GovernmentCommunityDevelopmentProject.ProjectType.Road, "Road work", 6 ether);
        communityProject.approveProject(1);
        vm.expectRevert(GovernmentCommunityDevelopmentProject.InvalidContractorAddress.selector);
        communityProject.assignContractor(1, address(0));
    }

    // ==========================================
    // 5. MILESTONE PAYMENT TESTS
    // ==========================================
    function test_ReleaseMilestonePayment_Success() public {
        // Setup project and funds (Scaled to 36 ether)
        communityProject.depositGovernmentFunds{value: 36 ether}();
        communityProject.createProject("Ward F", GovernmentCommunityDevelopmentProject.ProjectType.Road, "Road work", 36 ether);
        communityProject.approveProject(1);
        communityProject.assignContractor(1, contractor);

        uint256 payoutAmount = 12 ether; // Proportional 1/3 milestone payout
        uint256 contractorBalanceBefore = contractor.balance;

        vm.expectEmit(true, false, false, true);
        emit GovernmentCommunityDevelopmentProject.MilestonePaymentReleased(1, contractor, payoutAmount);
        
        communityProject.releaseMilestonePayment(1, payoutAmount);

        assertEq(contractor.balance, contractorBalanceBefore + payoutAmount);
        (, , , , , uint256 fundsAllocated, , ) = communityProject.projects(1);
        assertEq(fundsAllocated, payoutAmount);
        assertEq(communityProject.totalGovernmentFunding(), 24 ether); // 36 - 12 = 24 ether remaining
    }

    function test_RevertWhen_ReleasePaymentExceedsBudget() public {
        communityProject.depositGovernmentFunds{value: 36 ether}();
        communityProject.createProject("Ward G", GovernmentCommunityDevelopmentProject.ProjectType.Road, "Road work", 18 ether);
        communityProject.approveProject(1);
        communityProject.assignContractor(1, contractor);

        vm.expectRevert(GovernmentCommunityDevelopmentProject.PaymentExceedsTotalProjectBudget.selector);
        communityProject.releaseMilestonePayment(1, 20 ether); // 20 exceeds the 18 ether budget
    }

    function test_RevertWhen_TreasuryHasInsufficientBalance() public {
        // Create project with 36 ether budget but don't deposit ETH to treasury
        communityProject.createProject("Ward H", GovernmentCommunityDevelopmentProject.ProjectType.Road, "Road work", 36 ether);
        communityProject.approveProject(1);
        communityProject.assignContractor(1, contractor);

        vm.expectRevert(GovernmentCommunityDevelopmentProject.InsufficientTreasuryBalance.selector);
        communityProject.releaseMilestonePayment(1, 6 ether);
    }

    // ==========================================
    // 6. COMPLETE & CANCEL TESTS
    // ==========================================
    function test_CompleteProject_Success() public {
        communityProject.createProject("Ward I", GovernmentCommunityDevelopmentProject.ProjectType.BoleHole, "Borehole installation", 6 ether);
        communityProject.approveProject(1);
        communityProject.assignContractor(1, contractor);

        vm.expectEmit(true, false, false, true);
        emit GovernmentCommunityDevelopmentProject.ProjectCompleted(1);
        
        communityProject.completeProject(1);

        (, , , , , , GovernmentCommunityDevelopmentProject.ProjectStatus status, ) = communityProject.projects(1);
        assertTrue(status == GovernmentCommunityDevelopmentProject.ProjectStatus.Completed);
    }

    function test_CancelProject_Success() public {
        communityProject.createProject("Ward J", GovernmentCommunityDevelopmentProject.ProjectType.Drainage, "Drainage build", 6 ether);

        vm.expectEmit(true, false, false, true);
        emit GovernmentCommunityDevelopmentProject.ProjectCancelled(1);
communityProject.cancelProject(1);
(, , , , , , GovernmentCommunityDevelopmentProject.ProjectStatus status, ) = communityProject.projects(1);
assertTrue(status == GovernmentCommunityDevelopmentProject.ProjectStatus.Cancelled);
}
function test_RevertWhen_CancelInProgressProject() public {
communityProject.createProject("Ward K", GovernmentCommunityDevelopmentProject.ProjectType.Drainage, "Drainage build", 6 ether);
communityProject.approveProject(1);
communityProject.assignContractor(1, contractor);
vm.expectRevert(GovernmentCommunityDevelopmentProject.CannotCancelInProgressOrCompletedProjects.selector);
communityProject.cancelProject(1);
}
// ==========================================
// 7. ADMIN MANAGEMENT
// ==========================================
function test_TransferGovernmentAdmin_Success() public {
communityProject.transferGovernmentAdmin(newAdmin);
assertEq(communityProject.governmentAdmin(), newAdmin);
// Verify old admin loses privileges
vm.expectRevert(GovernmentCommunityDevelopmentProject.OnlyGovernmentAdminCanPerformThisAction.selector);
communityProject.createProject("Ward L", GovernmentCommunityDevelopmentProject.ProjectType.Road, "Road work", 3 ether);
}
function test_RevertWhen_TransferAdminToZeroAddress() public {
vm.expectRevert(GovernmentCommunityDevelopmentProject.InvalidGovernmentAdminAddress.selector);
communityProject.transferGovernmentAdmin(address(0));
}
}