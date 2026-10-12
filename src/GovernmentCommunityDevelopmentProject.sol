// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract GovernmentCommunityDevelopmentProject {

    error OnlyGovernmentAdminCanPerformThisAction();
    error MustSendETHToFundProjects();
    error ProjectDoesNotExist();
    error ProjectIsNotInProposedState();
    error totalBudgetMustBeGreaterThan0();
    error ProjectMustBeApprovedBeforeAssigningAContractor();
    error InvalidContractorAddress();
    error ProjectIsNotInProgress();
    error NoContractorAssigned();
    error InsufficientTreasuryBalance();
    error PaymentExceedsTotalProjectBudget();
    error ProjectMustBeInProgressToComplete();
    error CannotCancelInProgressOrCompletedProjects();
    error InvalidGovernmentAdminAddress();
    error PaymentTransferFailed();

    // Enum to list the type of Community Development Project.
    enum ProjectType { Drainage, Road, BoleHole }
    // Tracks the status of each milestone payment.
    enum ProjectStatus { Proposed, Approved, InProgress, Completed, Cancelled }
    
    // The core Project structure.
    struct Project {
        uint256 id;                      // Unique identifier for the community project
        string name;                     // Name/Ward of the community receiving the infrastructure
        ProjectType projectType;        // Type of project (Drainage, Road, or Borehole)
        string description;
        uint256 totalBudget;             // Total project cost in Wei/Tokens
        uint256 fundsAllocated;          // Total amount paid out to contractor so far
        ProjectStatus status;
        address contractor;              // Wallet address of the hired engineering firm  
    }
    
    // State variables
    address public governmentAdmin;
    uint256 public projectCount;
    uint256 public totalGovernmentFunding;
    mapping(uint256 => Project) public projects;

    // Events   
    event GovernmentFundsDeposited(address indexed government, uint256 amount);
    event ProjectCreated(uint256 indexed projectId, string name, ProjectType projectType, uint256 totalBudget);
    event ProjectApproved(uint256 indexed projectId);
    event ContractorAssigned(uint256 indexed projectId, address indexed contractor);
    event MilestonePaymentReleased(uint256 indexed projectId, address indexed contractor, uint256 amount);
    event ProjectCompleted(uint256 indexed projectId);
    event ProjectCancelled(uint256 indexed projectId);

    modifier onlyGovernment() {
        if (msg.sender != governmentAdmin) {
            revert OnlyGovernmentAdminCanPerformThisAction();
        }
        _;
    }
   
    constructor() {
        governmentAdmin = msg.sender;
    }

    // Deposit funds
    function depositGovernmentFunds() external payable onlyGovernment {
        if (msg.value == 0) {
            revert MustSendETHToFundProjects();
        }
        totalGovernmentFunding += msg.value;
        emit GovernmentFundsDeposited(msg.sender, msg.value);
    }

    // Create project
    function createProject(
        string memory _name,
        ProjectType _projectType,
        string memory _description,
        uint256 _totalBudget
    ) external onlyGovernment {
        if (_totalBudget == 0) {
            revert totalBudgetMustBeGreaterThan0();
        }

        projectCount++;
        projects[projectCount] = Project({
            id: projectCount,
            name: _name,
            projectType: _projectType,
            description: _description,
            totalBudget: _totalBudget,
            fundsAllocated: 0,
            status: ProjectStatus.Proposed,
            contractor: address(0)
        });

        emit ProjectCreated(projectCount, _name, _projectType, _totalBudget);
    }

    // Approve project
    function approveProject(uint256 _projectId) external onlyGovernment {
        Project storage project = projects[_projectId];
        if (project.id == 0) {
            revert ProjectDoesNotExist();
        }
        if (project.status != ProjectStatus.Proposed) {
            revert ProjectIsNotInProposedState();
        }
        
        project.status = ProjectStatus.Approved;
        emit ProjectApproved(_projectId);
    } 

    // Assign contractor
    function assignContractor(uint256 _projectId, address _contractor) external onlyGovernment {
        Project storage project = projects[_projectId];
        if (project.status != ProjectStatus.Approved) {
            revert ProjectMustBeApprovedBeforeAssigningAContractor();
        }
        if (_contractor == address(0)) {
            revert InvalidContractorAddress();
        }
       
        project.contractor = _contractor;
        project.status = ProjectStatus.InProgress;

        emit ContractorAssigned(_projectId, _contractor);
    }

    // Release milestone payment
    function releaseMilestonePayment(uint256 _projectId, uint256 _amount) external onlyGovernment {
        Project storage project = projects[_projectId];
        if (project.status != ProjectStatus.InProgress) {
            revert ProjectIsNotInProgress();
        }
        if (project.contractor == address(0)) {
            revert NoContractorAssigned();
        }
        if (_amount > address(this).balance) {
            revert InsufficientTreasuryBalance();
        }
        if (project.fundsAllocated + _amount > project.totalBudget) {
            revert PaymentExceedsTotalProjectBudget();
        }
        
        project.fundsAllocated += _amount;
        if (totalGovernmentFunding >= _amount) {
            totalGovernmentFunding -= _amount;
        } else {
            totalGovernmentFunding = 0;
        }

        (bool success, ) = payable(project.contractor).call{value: _amount}("");
        if (!success) {
            revert PaymentTransferFailed();
        }
       

        emit MilestonePaymentReleased(_projectId, project.contractor, _amount);
    }

    // Complete project
    function completeProject(uint256 _projectId) external onlyGovernment {
        Project storage project = projects[_projectId];
        if (project.status != ProjectStatus.InProgress) {
            revert ProjectMustBeInProgressToComplete();
        }
        
        project.status = ProjectStatus.Completed;
        emit ProjectCompleted(_projectId);
    }

    // Cancel project
    function cancelProject(uint256 _projectId) external onlyGovernment {
        Project storage project = projects[_projectId];
        if (project.status != ProjectStatus.Proposed && project.status != ProjectStatus.Approved) {
            revert CannotCancelInProgressOrCompletedProjects();
        }
        
        project.status = ProjectStatus.Cancelled;

        emit ProjectCancelled(_projectId);
    }

    // Transfer admin rights
    function transferGovernmentAdmin(address _newAdmin) external onlyGovernment {
        if (_newAdmin == address(0)) {
            revert InvalidGovernmentAdminAddress();
        }
        governmentAdmin = _newAdmin;
    }

    // Getter functions
    function getTreasuryBalance() external view returns (uint256) {
        return address(this).balance;
    }
}