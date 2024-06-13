module Health::health_marketplace {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{TxContext, sender};
    use sui::clock::{Clock, timestamp_ms};
    use sui::balance::{Self, Balance};
    use sui::sui::{SUI};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    
    use std::string::{Self, String};
    use std::vector;

    const ERROR_INVALID_GENDER: u64 = 0;
    const ERROR_INVALID_ACCESS: u64 = 1;
    const ERROR_INSUFFICIENT_FUNDS: u64 = 2;
    const ERROR_INVALID_TIME : u64 = 3;

    // Hospital Structure
    struct Hospital has key, store {
        id: UID,
        name: String,
        location: String,
        contact_info: String,
        hospital_type: String,
        bills: Table<address, Table<ID, Bill>>,
        balance: Balance<SUI>,
        bill_id: vector<ID> 
    }

    struct HospitalCap has key, store {
        id: UID,
        hospital: ID,
    }

    // Patient Structure
    struct Patient has key, store {
        id: UID,
        hospital: ID,
        name: String,
        age: u64,
        gender: String,
        contact_info: String,
        emergency_contact: String,
        admission_reason: String,
        discharge_date: u64,
    }

    // Billing Structure
    struct Bill has key, store {
        id: UID,
        patient_id: ID,
        charges: u64,
        payment_date: u64,
    }

    // Create a new hospital
    public fun create_hospital(name: String, location: String, contact_info: String, hospital_type: String, ctx: &mut TxContext) : (Hospital, HospitalCap) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        let hospital = Hospital {
            id: id_,
            name,
            location,
            contact_info,
            hospital_type,
            bills: table::new(ctx),
            balance: balance::zero(),
            bill_id:vector::empty()
        };
        let cap = HospitalCap {
            id: object::new(ctx),
            hospital: inner_,
        };
        (hospital, cap)
    }

     // Admit a patient
    public fun admit_patient(hospital: ID, name: String, age: u64, gender: String, contact_info: String, emergency_contact: String, admission_reason: String, date: u64, c: &Clock, ctx: &mut TxContext): Patient {
        assert!(gender == string::utf8(b"MALE") || gender == string::utf8(b"FAMALE"), ERROR_INVALID_GENDER);
        Patient {
            id: object::new(ctx),
            hospital,
            name,
            age,
            gender,
            contact_info,
            emergency_contact,
            admission_reason,
            discharge_date: timestamp_ms(c) + date,
        }
    }

    // Generate a detailed bill for a patient
    public fun generate_bill(cap: &HospitalCap, hospital: &mut Hospital, patient_id: ID, charges: u64, date: u64, c: &Clock, user: address, ctx: &mut TxContext) {
        assert!(cap.hospital == object::id(hospital), ERROR_INVALID_ACCESS);
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        vector::push_back(&mut hospital.bill_id, inner_);
        let bill = Bill {
            id: id_,
            patient_id,
            charges,
            payment_date: timestamp_ms(c) + date,
        };
        if (!table::contains(&hospital.bills, user)) {
            let table = table::new<ID, Bill>(ctx);
            table::add(&mut hospital.bills, user, table);
        };
        let user_table = table::borrow_mut(&mut hospital.bills, user);
        table::add(user_table, inner_, bill);
    }

    // Pay a bill
    public fun pay_bill(hospital: &mut Hospital, patient: &mut Patient, bill: ID,  coin: Coin<SUI>, c: &Clock, ctx: &mut TxContext) {
        let user_table = table::borrow_mut(&mut hospital.bills, sender(ctx));
        let bill = table::remove(user_table, bill);
        assert!(bill.patient_id == object::id(patient), ERROR_INVALID_ACCESS);
        assert!(coin::value(&coin) == bill.charges, ERROR_INSUFFICIENT_FUNDS);
        assert!(bill.payment_date < timestamp_ms(c), ERROR_INVALID_TIME);
        let Bill {
            id,
            patient_id: _,
            charges: _,
            payment_date: _
        } = bill;
        object::delete(id);
        // join the balance 
        let balance_ = coin::into_balance(coin);
        balance::join(&mut hospital.balance, balance_);
    }

    public fun withdraw(cap: &HospitalCap, hospital: &mut Hospital, ctx: &mut TxContext) : Coin<SUI> {
        assert!(cap.hospital == object::id(hospital), ERROR_INVALID_ACCESS);
        let balance_ = balance::withdraw_all(&mut hospital.balance);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

    // // =================== Public view functions ===================
    public fun get_hospital_balance(hospital: &Hospital) : u64 {
        balance::value(&hospital.balance)
    }

    public fun get_bill_amount(hospital: &Hospital, bill: ID, ctx: &mut TxContext) : u64 {
        let user_table = table::borrow(&hospital.bills, sender(ctx));
        let bill = table::borrow(user_table, bill);
        bill.charges
    }

    // Test only 
    public fun get_patient_id(self: &Patient) : ID {
        let id_ = object::id(self);
        id_
    }
   public fun get_bill_id(self: &Hospital) : ID {
        let id_ = vector::borrow(&self.bill_id, 0);
        *id_
    }}