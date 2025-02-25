#[test_only]
module projectOwnerAdr::airdrop_tests {
    use std::string::{utf8};
    use std::signer;
    use std::vector;
    use supra_framework::coin::{Self, BurnCapability, MintCapability};
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
        aptos_framework: &signer,
        project_owner: &signer,
        user1: &signer,
        user2: &signer
    ): (BurnCapability<TestCoin>, MintCapability<TestCoin>) {
        // Initialize timestamp for testing
        timestamp::set_time_has_started_for_testing(aptos_framework);
        
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
        
        (burn_cap, mint_cap)
    }
    
    #[test]
    /// Test basic initialization of the airdrop module
    fun test_initialize() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        // Initialize airdrop
        airdrop::initialize<TestCoin>(&project_owner);
        
        // Check that claims are initially disabled
        assert!(!airdrop::is_claims_enabled<TestCoin>(), 0);
        
        // Check that total allocation is initially 0
        assert!(airdrop::get_total_allocation<TestCoin>() == 0, 1);
        
        // Check that airdrop balance is initially 0
        assert!(airdrop::get_airdrop_balance<TestCoin>() == 0, 2);
    }
    
    #[test]
    /// Test setting and overriding allocations
    fun test_set_allocation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create address and amount vectors
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        vector::push_back(&mut addresses, USER2);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 500);
        
        // Set allocation
        airdrop::set_allocation<TestCoin>(&project_owner, addresses, amounts, utf8(b"Test Reason"));
        
        // Verify total allocation
        assert!(airdrop::get_total_allocation<TestCoin>() == 1500, 3);
        
        // Override the allocation with new amounts
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        vector::push_back(&mut addresses2, USER2);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 2000);
        vector::push_back(&mut amounts2, 1000);
        
        airdrop::set_allocation<TestCoin>(&project_owner, addresses2, amounts2, utf8(b"Test Reason"));
        
        // Verify total allocation is updated
        assert!(airdrop::get_total_allocation<TestCoin>() == 3000, 4);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test the basic claim functionality
    fun test_basic_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(&project_owner, addresses, amounts, utf8(b"Test Reason"));
        
        // Deposit funds to the airdrop
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User claims the allocation
        airdrop::claim<TestCoin>(&user1);
        
        // Verify the user received the funds
        assert!(coin::balance<TestCoin>(USER1) == 1000, 5);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that a user cannot claim twice for the same reason
    fun test_no_double_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(&project_owner, addresses, amounts, utf8(b"Test Reason"));
        
        // Deposit funds and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 2000); // Extra for potential double claim
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // First claim should succeed
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 6);
        
        // Second claim should not add more funds
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 7); // Balance shouldn't change
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test claiming new reasons after already claiming old ones
    fun test_claim_new_reasons() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create first allocation
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(&project_owner, addresses1, amounts1, utf8(b"Reason1"));
        
        // Deposit funds and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 2000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User claims first allocation
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 8);
        
        // Create second allocation with new reason
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 500);
        
        airdrop::set_allocation<TestCoin>(&project_owner, addresses2, amounts2, utf8(b"Reason2"));
        
        // User should be able to claim the new reason
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1500, 9);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test that users cannot claim from modified allocations they already claimed
    fun test_modified_allocation_no_double_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create first allocation
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(&project_owner, addresses1, amounts1, utf8(b"Test Reason"));
        
        // Deposit funds and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User claims allocation
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 10);
        
        // Modify the allocation with increased amount
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 2000); // Increased amount
        
        airdrop::set_allocation<TestCoin>(&project_owner, addresses2, amounts2, utf8(b"Test Reason"));
        
        // User should not be able to claim again from the modified allocation
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 11); // Balance shouldn't change
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test multiple reasons with multiple claims
    fun test_multiple_reasons() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
        // Create multiple reason allocations
        let i = 0;
        let total_amount = 0;
        
        while (i < 5) {
            let addr = vector::empty<address>();
            let amt = vector::empty<u64>();
            
            vector::push_back(&mut addr, USER1);
            vector::push_back(&mut amt, 100);
            total_amount = total_amount + 100;
            
            // Create a unique reason string for each allocation
            let reason_bytes = vector::empty<u8>();
            vector::append(&mut reason_bytes, b"Reason");
            vector::push_back(&mut reason_bytes, (48 + i + 1)); // Convert to ASCII digit
            
            airdrop::set_allocation<TestCoin>(
                &project_owner,
                addr,
                amt,
                utf8(reason_bytes)
            );
            
            i = i + 1;
        };
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, total_amount);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims all reasons at once
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 500, 19); // 5 reasons * 100 tokens
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Simulates a large airdrop with many users (scaled down for testing purposes)
    fun test_large_airdrop_simulation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, &user1, &user2);
        
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
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, total_allocation * 2); // Double to cover both users
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims all reasons at once
        airdrop::claim<TestCoin>(&user1);
        
        // To verify gas usage, we would observe the transaction costs in a real environment
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
} 