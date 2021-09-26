 pragma solidity ^0.8.0;

contract KYCContract{
    
    //Customer Struct
    struct Customer {
        bytes32 customerName;
        bytes32 customerDataHash;
        uint upvotes;
        uint downvotes;
        address bankAddress;
        bool kycStatus;
	}
	
	//Bank Struct
	struct Bank {
	    bytes32 bankName;
	    address bankAddress;
	    bytes32 regNumber;
	    uint reports;
	    uint kycCount;
	    bool kycPermission;
	}
	
	//KYCRequest Struct
	struct KYCRequest {
	    bytes32 customerName;
	    bytes32 customerDataHash;
	    address bankAddress;
	}
	
	//Address of the Contract Deployer
	address admin;
	//Total Number of Banks in the network at a given time
	uint totalBanks;
	
	//Base Constructor Called during condition
	constructor() {
		//Setting admin to be the address of the deployer
	    admin = msg.sender;
	    totalBanks = 0;
	}
	
	//Mapping to check if a customer exists using customer name
	mapping(bytes32 => Customer) private customersMap;
	//Mapping to check if Bank exists using Bank address
	mapping(address => Bank) private banksMap;
	//Mapping of mapping to get unique KYCRequest
	mapping(bytes32 => mapping(bytes32 => KYCRequest)) private kycRequests;
	
	modifier adminCheck {
	    require(msg.sender == admin, "Admin Accessible Only");
	    _;
	}
	
	modifier bankCheck(address addr) {
        require(banksMap[addr].bankAddress != address(0), "Bank doesn't exist");
        _;
	}
	
	modifier validBank {
	    require(banksMap[msg.sender].kycPermission == true, "Bank is Not Valid");
	    _;
	}
	
	modifier customerExist(bytes32 name) {
	    require(customersMap[name].bankAddress != address(0), "Customer Doesn't exist");
	    _;
	}
	//Valid Bank Adds a KYC Request if the same request doesn't exist or if the customer isn't already enrolled
	function addRequest(bytes32 name, bytes32 data) validBank external returns(uint8) {
	   require(kycRequests[name][data].bankAddress != address(0), "Request already exists");
	   require(customersMap[name].bankAddress == address(0), "Customer Exists already");
	   kycRequests[name][data] = KYCRequest(name,data,msg.sender);
	   banksMap[msg.sender].kycCount++;
	   return 1;
	}
	
	//Valid Bank Adds a customer if the Customer doesn't exist
	function addCustomer(bytes32 name, bytes32 data) validBank external returns(uint8) {
	    require(customersMap[name].bankAddress == address(0), "Customer Exists already");
	    customersMap[name] = Customer(name,data,0,0,msg.sender,true); 
	    return 1;
	}
	
	//Valid Bank removes request from the KYCRequest Mapping
	function removeRequest(bytes32 name, bytes32 data) external validBank returns(uint8) {
	    delete kycRequests[name][data];
	    return 1;
	}
	
	//Removes customer from the set
	function removeCustomer(bytes32 name) external validBank returns(uint8) {
	    delete customersMap[name];
	    return 1;
	}
	
	//Modify the customer's KYC data
	function modifyCustomer(bytes32 name, bytes32 newHash) validBank customerExist(name) external returns(uint8) {
	    bytes32 oldHash = customersMap[name].customerDataHash;
	    customersMap[name].customerDataHash = newHash;
	    customersMap[name].upvotes = 0;
	    customersMap[name].downvotes = 0;
	    KYCRequest memory oldKycRequest =  kycRequests[name][oldHash];
	    delete kycRequests[name][oldHash];
	    oldKycRequest.customerDataHash = newHash;
	    kycRequests[name][newHash] = oldKycRequest;
	    return 1;
	}
	
	//Fetch Customer Details
	function viewCustomer(bytes32 name) external view customerExist(name) returns(bytes32,bytes32) {
        return (name,customersMap[name].customerDataHash);
	}

	//Upvote Customer KYC Data and calculate the KYC Permission
	function upvote(bytes32 name) external validBank customerExist(name) returns(uint8) {
	    ++customersMap[name].upvotes;
	    customersMap[name].kycStatus = setKycPermissionAfterVoting(customersMap[name].upvotes, customersMap[name].downvotes);
	    return 1;
	}
	
	//Downvote Customer KYC Data and calculate the KYC Permission
	function downvote(bytes32 name) external validBank customerExist(name) returns(uint8) {
	    ++customersMap[name].downvotes;
	    customersMap[name].kycStatus = setKycPermissionAfterVoting(customersMap[name].upvotes, customersMap[name].downvotes);
	    return 1;
	}
	
	//If total Banks are greater than 10 and downvotes is greater than totalBanks
	function setKycPermissionAfterVoting(uint upvotes, uint downvotes) private view returns(bool) {
	    bool ans = false;
	    if(totalBanks > 10 && 3*downvotes > totalBanks){
	        ans = false;
	    } else if(downvotes >= upvotes){
	        ans = false;
	    } else {
	        ans = true;
	    }
	    return ans;
	}
	
	//Report the bank and check if it can set Kyc Permission
	function reportBank(address reportedBank) external validBank bankCheck(reportedBank) returns(uint8){
	    banksMap[reportedBank].reports++;
	    if(totalBanks > 10 && 3*banksMap[reportedBank].reports > totalBanks){
	        banksMap[reportedBank].kycPermission = false;
	    } else {
	    	banksMap[reportedBank].kycPermission = true;
	    }
	    return 1;
	}
	
	//Get Bank Reports for a bank
	function getBankReports(address banks) external bankCheck(banks) view returns(uint) {
	    return banksMap[banks].reports;
	}
	
	//Get Customer's KYC Status
	function getCustomerStatus(bytes32 name) external view returns(bool) {
	    return customersMap[name].kycStatus;
	}
	
	//Get the Bank details
	function viewBank(address banks) external view bankCheck(banks) returns(Bank memory) {
	    return banksMap[banks];
	}
	
	//Add bank to Mapping Only Admin can
	function addBank(bytes32 name, address addr, bytes32 registration) adminCheck external returns(uint8) {
	    require(banksMap[addr].bankAddress == address(0), "Bank already exists");
	    banksMap[addr] = Bank(name, addr, registration, 0, 0, true);
	    totalBanks++;
	    return 1;
	}
	
	//Modify the KYC Permission of a bank
	function modifyBankKYCPermission(address addr) adminCheck bankCheck(addr) external returns(uint8) {
	    banksMap[addr].kycPermission = !banksMap[addr].kycPermission;
	    return 1;
	}
	
	//Remove bank from Bank Mapping
	function removeBank(address banks) adminCheck bankCheck(banks) external returns(uint8) {
	    delete banksMap[banks];
	    if(totalBanks>0){
	        totalBanks--;
	    }
	    return 1;
	}
}
