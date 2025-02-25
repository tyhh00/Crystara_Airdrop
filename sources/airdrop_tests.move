#[test_only]
module projectOwnerAdr::airdrop_tests {
    use std::string::{String, utf8};
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
        users: vector<&signer>,
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
        
        let i = 0;
        let len = vector::length(&users);
        while (i < len) {
            let user = vector::borrow(&users, i);
            coin::register<TestCoin>(user);
            i = i + 1;
        };
        
        // Mint some coins to project owner for airdrop funding
        coin::mint<TestCoin>(100000000, &mint_cap, signer::address_of(project_owner));
        
        // Initialize airdrop module
        airdrop::initialize<TestCoin>(project_owner);
        
        (burn_cap, mint_cap)
    }
    
    #[test]
    /// Test basic initialization of the airdrop module
    fun test_initialize() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        
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
    /// Test setting and updating allocations
    fun test_set_allocation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        vector::push_back(&mut users, &user2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Create addresses and amounts for allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        vector::push_back(&mut addresses, USER2);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 2000);
        
        // Set allocation
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        // Check total allocation
        assert!(airdrop::get_total_allocation<TestCoin>() == 3000, 3);
        
        // Check user allocations
        let (user1_reasons, user1_amounts) = airdrop::get_user_allocations<TestCoin>(USER1);
        assert!(vector::length(&user1_reasons) == 1, 4);
        assert!(*vector::borrow(&user1_amounts, 0) == 1000, 5);
        
        let (user2_reasons, user2_amounts) = airdrop::get_user_allocations<TestCoin>(USER2);
        assert!(vector::length(&user2_reasons) == 1, 6);
        assert!(*vector::borrow(&user2_amounts, 0) == 2000, 7);
        
        // Test updating an existing allocation
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        vector::push_back(&mut addresses2, USER2);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 1500);
        vector::push_back(&mut amounts2, 2500);
        
        // Update allocation with same reason
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"First Airdrop")
        );
        
        // Check updated total allocation
        assert!(airdrop::get_total_allocation<TestCoin>() == 4000, 8);
        
        // Check updated user allocations
        let (user1_reasons, user1_amounts) = airdrop::get_user_allocations<TestCoin>(USER1);
        assert!(*vector::borrow(&user1_amounts, 0) == 1500, 9);
        
        let (user2_reasons, user2_amounts) = airdrop::get_user_allocations<TestCoin>(USER2);
        assert!(*vector::borrow(&user2_amounts, 0) == 2500, 10);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test depositing funds and enabling claims
    fun test_deposit_and_enable_claims() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        vector::push_back(&mut users, &user2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Set allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        vector::push_back(&mut addresses, USER2);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        // Try enabling claims without sufficient deposit
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Check claims still disabled
        assert!(!airdrop::is_claims_enabled<TestCoin>(), 11);
        
        // Deposit less than needed
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 2000);
        assert!(airdrop::get_airdrop_balance<TestCoin>() == 2000, 12);
        
        // Try enabling again (should still fail)
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        assert!(!airdrop::is_claims_enabled<TestCoin>(), 13);
        
        // Deposit the rest needed
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        assert!(airdrop::get_airdrop_balance<TestCoin>() == 3000, 14);
        
        // Now enable claims (should succeed)
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        assert!(airdrop::is_claims_enabled<TestCoin>(), 15);
        
        // Disable claims
        airdrop::enable_claims<TestCoin>(&project_owner, false);
        assert!(!airdrop::is_claims_enabled<TestCoin>(), 16);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test basic claiming functionality
    fun test_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        vector::push_back(&mut users, &user2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Set allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        vector::push_back(&mut addresses, USER2);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        vector::push_back(&mut amounts, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        // Deposit funds
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        
        // Enable claims
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims
        airdrop::claim<TestCoin>(&user1);
        
        // Check user1's balance
        assert!(coin::balance<TestCoin>(USER1) == 1000, 17);
        
        // Check that user1 can't claim again
        let (user1_reasons, user1_amounts) = airdrop::get_user_allocations<TestCoin>(USER1);
        assert!(vector::length(&user1_reasons) == 0, 18);
        
        // User2 claims
        airdrop::claim<TestCoin>(&user2);
        
        // Check user2's balance
        assert!(coin::balance<TestCoin>(USER2) == 2000, 19);
        
        // Check airdrop balance after claims
        assert!(airdrop::get_airdrop_balance<TestCoin>() == 0, 20);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test claiming with multiple allocation reasons
    fun test_multiple_reasons() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        vector::push_back(&mut users, &user2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Set first allocation
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses1,
            amounts1,
            utf8(b"First Airdrop")
        );
        
        // Set second allocation
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        vector::push_back(&mut addresses2, USER2);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 500);
        vector::push_back(&mut amounts2, 1500);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"Second Airdrop")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 3000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // Check user1 allocations (should have both reasons)
        let (user1_reasons, user1_amounts) = airdrop::get_user_allocations<TestCoin>(USER1);
        assert!(vector::length(&user1_reasons) == 2, 21);
        assert!(*vector::borrow(&user1_amounts, 0) == 1000, 22);
        assert!(*vector::borrow(&user1_amounts, 1) == 500, 23);
        
        // User1 claims (both reasons)
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1500, 24);
        
        // Check that user1 has no more allocations
        let (user1_reasons_after, _) = airdrop::get_user_allocations<TestCoin>(USER1);
        assert!(vector::length(&user1_reasons_after) == 0, 25);
        
        // User2 claims (only second reason)
        airdrop::claim<TestCoin>(&user2);
        assert!(coin::balance<TestCoin>(USER2) == 1500, 26);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test claiming after a new reason is added
    fun test_claim_after_new_reason() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Set first allocation
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses1,
            amounts1,
            utf8(b"First Airdrop")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims first allocation
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 27);
        
        // Set second allocation
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 500);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"Second Airdrop")
        );
        
        // Deposit more funds for second allocation
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 500);
        
        // Check user1 can claim new allocation
        let (user1_reasons, user1_amounts) = airdrop::get_user_allocations<TestCoin>(USER1);
        assert!(vector::length(&user1_reasons) == 1, 28);
        assert!(*vector::borrow(&user1_amounts, 0) == 500, 29);
        
        // User1 claims second allocation
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1500, 30);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test trying to modify a reason after it's been claimed
    fun test_modify_reasons_after_claim() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Set first allocation
        let addresses1 = vector::empty<address>();
        vector::push_back(&mut addresses1, USER1);
        
        let amounts1 = vector::empty<u64>();
        vector::push_back(&mut amounts1, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses1,
            amounts1,
            utf8(b"First Airdrop")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 2000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User1 claims first allocation
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 1000, 31);
        
        // Modify the same reason with higher amount
        let addresses2 = vector::empty<address>();
        vector::push_back(&mut addresses2, USER1);
        
        let amounts2 = vector::empty<u64>();
        vector::push_back(&mut amounts2, 2000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses2,
            amounts2,
            utf8(b"First Airdrop")
        );
        
        // Check user1 can't claim modified allocation (already claimed)
        let (user1_reasons, _) = airdrop::get_user_allocations<TestCoin>(USER1);
        assert!(vector::length(&user1_reasons) == 0, 32);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    #[expected_failure(abort_code = 2)] // EVECTOR_LENGTH_MISMATCH
    /// Test that imbalanced vectors are rejected
    fun test_imbalanced_vectors() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        
        let users = vector::empty<&signer>();
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Create imbalanced vectors
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        vector::push_back(&mut addresses, USER2);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        // Missing second amount!
        
        // This should fail due to mismatched vector lengths
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    #[expected_failure(abort_code = 1)] // ENOT_OWNER
    /// Test that only the owner can set allocations
    fun test_unauthorized_set_allocation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Create allocation data
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        // User1 tries to set allocation (should fail)
        airdrop::set_allocation<TestCoin>(
            &user1,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    #[expected_failure(abort_code = 4)] // ECLAIMS_NOT_ENABLED
    /// Test that claims can't be processed when disabled
    fun test_claim_when_disabled() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Set allocation
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        // Deposit but don't enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        
        // Try to claim (should fail since claims are disabled)
        airdrop::claim<TestCoin>(&user1);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    #[expected_failure(abort_code = 5)] // ENO_ALLOCATION
    /// Test that users without allocations can't claim
    fun test_claim_no_allocation() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        let user2 = account::create_account_for_test(USER2);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        vector::push_back(&mut users, &user2);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Set allocation only for user1
        let addresses = vector::empty<address>();
        vector::push_back(&mut addresses, USER1);
        
        let amounts = vector::empty<u64>();
        vector::push_back(&mut amounts, 1000);
        
        airdrop::set_allocation<TestCoin>(
            &project_owner,
            addresses,
            amounts,
            utf8(b"First Airdrop")
        );
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 1000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User2 tries to claim (should fail - no allocation)
        airdrop::claim<TestCoin>(&user2);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    #[test]
    /// Test claiming after multiple allocations for the same user
    fun test_multiple_allocations_same_user() {
        let aptos_framework = account::create_account_for_test(@0x1);
        let project_owner = account::create_account_for_test(PROJECT_OWNER);
        let user1 = account::create_account_for_test(USER1);
        
        let users = vector::empty<&signer>();
        vector::push_back(&mut users, &user1);
        
        let (burn_cap, mint_cap) = setup_test(&aptos_framework, &project_owner, users);
        
        // Set multiple allocations for same user with different reasons
        let reasons = vector[utf8(b"Reason1"), utf8(b"Reason2"), utf8(b"Reason3")];
        let amounts = vector[1000u64, 2000u64, 3000u64];
        
        let i = 0;
        while (i < 3) {
            let addr = vector::empty<address>();
            vector::push_back(&mut addr, USER1);
            
            let amt = vector::empty<u64>();
            vector::push_back(&mut amt, *vector::borrow(&amounts, i));
            
            airdrop::set_allocation<TestCoin>(
                &project_owner,
                addr,
                amt,
                *vector::borrow(&reasons, i)
            );
            
            i = i + 1;
        };
        
        // Deposit and enable claims
        airdrop::deposit_to_airdrop<TestCoin>(&project_owner, 6000);
        airdrop::enable_claims<TestCoin>(&project_owner, true);
        
        // User should be able to claim all at once
        airdrop::claim<TestCoin>(&user1);
        assert!(coin::balance<TestCoin>(USER1) == 6000, 33);
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
} 