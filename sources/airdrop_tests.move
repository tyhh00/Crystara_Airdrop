#[test_only]
module projectOwnerAdr::airdrop_tests {
    use std::string::{utf8};
    use std::signer;
    use std::vector;
    use supra_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    use supra_framework::account;
    use supra_framework::timestamp;
    use projectOwnerAdr::airdrop;

    // Test coin
    struct TestCoin {}

    // Test constants
    const PROJECT_OWNER: address = @projectOwnerAdr;
    const USER1: address = @0x111;
    const USER2: address = @0x222;
    const USER3: address = @0x333;
    
    // Setup function for tests
    fun setup_test(
        supra_framework: &signer,
        project_owner: &signer,
        user1: &signer,
        user2: &signer
    ): (BurnCapability<TestCoin>, FreezeCapability<TestCoin>, MintCapability<TestCoin>) {
        // Initialize timestamp for testing
        timestamp::set_time_has_started_for_testing(supra_framework);
        
        // Initialize test coin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TestCoin>(
            project_owner,
            utf8(b"Test Coin"),
            utf8(b"TEST"),
            6,
            false,
        );
        
        // Register users with the coin
        coin::register<TestCoin>(project_owner);
        coin::register<TestCoin>(user1);
        coin::register<TestCoin>(user2);
        
        // Mint some coins to project owner for airdrop funding
        let coins = coin::mint<TestCoin>(100000000, &mint_cap);
        coin::deposit(signer::address_of(project_owner), coins);
        
        // Initialize airdrop module
        airdrop::initialize<TestCoin>(project_owner);
        
        (burn_cap, freeze_cap, mint_cap)
    }
    
    #[test]
    /// Test basic initialization of the airdrop module
    fun test_initialize() {
        account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        account::create_account_for_test(USER1);
        account::create_account_for_test(USER2);
        
        // First initialize the TestCoin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TestCoin>(
            &project_owner,
            utf8(b"Test Coin"),
            utf8(b"TEST"),
            6,
            false,
        );

        // Now initialize airdrop
        airdrop::initialize<TestCoin>(&project_owner);
        
        // Check that claims are initially disabled
        assert!(!airdrop::is_claims_enabled<TestCoin>(), 0);
        
        // Check that total allocation is initially 0
        assert!(airdrop::get_total_allocation<TestCoin>() == 0, 1);
        
        // Check that airdrop balance is initially 0
        assert!(airdrop::get_airdrop_balance<TestCoin>() == 0, 2);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test setting and overriding allocations
    fun test_set_allocation() {
        let supra_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&supra_framework, &project_owner, &user1, &user2);
        
        // Create address and amount vectors
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        // Set allocation
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Check that total allocation is 1000
        assert!(airdrop::get_total_allocation<TestCoin>() == 1000, 3);
        
        // Update allocation to 2000
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Check that total allocation is updated to 2000
        assert!(airdrop::get_total_allocation<TestCoin>() == 2000, 4);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test basic deposit and claim
    fun test_basic_claim() {
        let supra_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&supra_framework, &project_owner, &user1, &user2);
        
        // Set allocation for user1
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims their allocation
        airdrop::claim<TestCoin>(&user1);
        
        // Check that user1 received the tokens
        assert!(coin::balance<TestCoin>(USER1) == 1000, 5);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    #[expected_failure(abort_code = 393221, location = projectOwnerAdr::airdrop)]
    /// Test that a user cannot claim twice
    fun test_no_double_claim() {
        let supra_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&supra_framework, &project_owner, &user1, &user2);
        
        // Set allocation for user1
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims their allocation
        airdrop::claim<TestCoin>(&user1);
        
        // Check that user1 received the tokens
        assert!(coin::balance<TestCoin>(USER1) == 1000, 6);
        
        // User1 tries to claim again (should fail with ENO_ALLOCATION)
        airdrop::claim<TestCoin>(&user1);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test claiming from multiple reasons
    fun test_multiple_reasons() {
        let supra_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&supra_framework, &project_owner, &user1, &user2);
        
        // Set allocation for user1 with reason1
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Reason1")
        );
        
        // Set allocation for user1 with reason2
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Reason2")
        );
        
        // Deposit to airdrop (enough for both reasons)
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims all allocations
        airdrop::claim<TestCoin>(&user1);
        
        // Check that user1 received the tokens from both reasons
        assert!(coin::balance<TestCoin>(USER1) == 3000, 7);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test claiming new reasons after claiming existing ones
    fun test_claim_new_reasons() {
        let supra_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&supra_framework, &project_owner, &user1, &user2);
        
        // Set allocation for user1 with reason1
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Reason1")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 10000); // Deposit enough for all future allocations
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims their allocation
        airdrop::claim<TestCoin>(&user1);
        
        // Check that user1 received the tokens
        assert!(coin::balance<TestCoin>(USER1) == 1000, 8);
        
        // Set a new allocation with reason2
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Reason2")
        );
        
        // User1 claims the new allocation
        airdrop::claim<TestCoin>(&user1);
        
        // Check that user1 received the new tokens
        assert!(coin::balance<TestCoin>(USER1) == 3000, 9);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    #[expected_failure(abort_code = 393221, location = projectOwnerAdr::airdrop)] // ENO_ALLOCATION error code
    /// Test that modifying an allocation doesn't allow a user to claim twice
    fun test_modified_allocation_no_double_claim() {
        let supra_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&supra_framework, &project_owner, &user1, &user2);
        
        // Set allocation for user1
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // Deposit to airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 2000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims their allocation
        airdrop::claim<TestCoin>(&user1);
        
        // Check that user1 received the tokens
        assert!(coin::balance<TestCoin>(USER1) == 1000, 10);
        
        // Modify allocation for user1 (increase to 1500)
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1500);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"Test Allocation")
        );
        
        // User1 tries to claim again (should fail with ENO_ALLOCATION)
        airdrop::claim<TestCoin>(&user1);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Simulates a large airdrop with many users (scaled down for testing purposes)
    fun test_large_airdrop_simulation() {
        let supra_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, freeze_cap, mint_cap) = setup_test(&supra_framework, &project_owner, &user1, &user2);
        
        // Create 50 allocations split across 5 reasons to simulate a large airdrop
        // This tests efficiency without hitting gas limits
        let total_allocation = 0u64;
        let reason_count = 5;
        let user_per_reason = 10; // Simulate 50 total allocations (would be 100k in production)
        
        let r = 0;
        while (r < reason_count) {
            let addresses = vector::empty<address>();
            let amounts = vector::empty<u64>();
            
            // For each reason, add multiple users
            let u = 0;
            while (u < user_per_reason) {
                // In a real test we would have 100k different addresses
                // But for this simulation we'll alternate between user1 and user2
                if (u % 2 == 0) {
                    vector::push_back(&mut addresses, USER1);
                } else {
                    vector::push_back(&mut addresses, USER2);
                };
                
                let amount = 100 + (r * 10) + u;
                vector::push_back(&mut amounts, amount);
                
                if (u % 2 == 0) {
                    total_allocation = total_allocation + amount;
                } else {
                    // Add user2's allocation to the total as well
                    total_allocation = total_allocation + amount;
                };
                
                u = u + 1;
            };
            
            // Create unique reason string by appending the reason number
            let reason_bytes = vector::empty<u8>();
            vector::append(&mut reason_bytes, b"BatchReason");
            vector::push_back(&mut reason_bytes, ((48 + r) as u8)); // Convert number to ASCII digit
            
            airdrop::set_allocation<TestCoin>(
                &project_owner,
                addresses,
                amounts,
                utf8(reason_bytes)
            );
            
            r = r + 1;
        };
        
        // Deposit enough to cover all allocations
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, total_allocation + 1000); // Add extra to be safe
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims all reasons at once
        airdrop::claim<TestCoin>(&user1);
        
        // Also have user2 claim
        airdrop::claim<TestCoin>(&user2);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);
    }
} 