module appointment_booking::appointment_booking {
    use sui::transfer;
    use sui::table::{Self, Table};
    use std::string::{Self, String};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};


    // Constants to handle errors
    const InvalidAppointment: u64 = 1;
    const AppointmentAlreadyExists : u64 = 2;
    const InvalidClinic: u64 = 3;
    const InvalidPatient: u64 = 4;
    const InvalidAmount : u64 = 5;
    

    struct Appointment has key, store {
        id: UID,
        patient: address,
        clinic: address,
        description: vector<u8>,
        booking_date: vector<u8>,
        booking_time: vector<u8>, 
        created_at: u64,  
        status: String // pending, confirmed, cancelled
    }
    struct Clinic has key, store {
        id: UID,
        name: vector<u8>,
        address: vector<u8>,
        phone: vector<u8>,
        email: vector<u8>,
        clinic_address: address,
        wallet: Balance<SUI>,
        appointments: Table<u64, Appointment>
    }

    struct Patient has key, store {
        id: UID,
        name: vector<u8>,
        patient_address: address,
        phone: vector<u8>,
        wallet: Balance<SUI>,
    }



    // Function to create a new Clinic 
    public fun new_clinic(
        name: vector<u8>,
        address: vector<u8>,
        phone: vector<u8>,
        email: vector<u8>,
        clinic_address: address,
        ctx: &mut TxContext
    ) : Clinic {
        let clinic = Clinic {
            id: object::new(ctx),
            name: name,
            address: address,
            phone: phone,
            email: email,
            clinic_address: clinic_address,
            wallet: balance::zero(),
            appointments: table::new<u64, Appointment>(ctx)
        };

        clinic
    }

    // Function to create a new Patient
    public fun new_patient(
        name: vector<u8>,
        address: address,
        phone: vector<u8>,
        ctx: &mut TxContext
    ) : Patient {
        let patient = Patient {
            id: object::new(ctx),
            name: name,
            patient_address: address,
            phone: phone,
            wallet: balance::zero()
        };

        patient
      
    }

    // Function to create a new Appointment
    public fun new_appointment(
        patient: &mut Patient,
        clinic: &mut Clinic,
        description: vector<u8>,
        booking_date: vector<u8>,
        booking_time: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let created_at = clock::timestamp_ms(clock);
        // Check if the patient address exists.
        assert!(patient.patient_address != clinic.clinic_address, InvalidPatient);
        // Check if the clinic address exists.
        assert!(clinic.clinic_address != patient.patient_address, InvalidClinic);
        // Check if the appointment already exists.
        assert!(!table::contains(&clinic.appointments, created_at), AppointmentAlreadyExists);

        let appointment = Appointment {
            id: object::new(ctx),
            patient: patient.patient_address,
            clinic: clinic.clinic_address,
            description: description,
            booking_date: booking_date,
            booking_time: booking_time,
            created_at: created_at,
            status:  string::utf8(b"Pending"),
        };

        // Add the appointment to the clinic's appointments.
        table::add<u64, Appointment>(&mut clinic.appointments, created_at, appointment);
    }

    // Function to get the appointment details.
    public fun get_appointment_details(appointment: &Appointment) : (vector<u8>, vector<u8>, vector<u8>, u64, String) {
        (
            appointment.description,
            appointment.booking_date,
            appointment.booking_time,
            appointment.created_at,
            appointment.status
        )
    }

    // Function to get the clinic details.
    public fun get_clinic_details(clinic: &Clinic) : (vector<u8>, vector<u8>, vector<u8>, vector<u8>, address) {
        (
            clinic.name,
            clinic.address,
            clinic.phone,
            clinic.email,
            clinic.clinic_address
        )
    }

    // Function to get the patient details.
    public fun get_patient_details(patient: &Patient) : (vector<u8>, address, vector<u8>) {
        (
            patient.name,
            patient.patient_address,
            patient.phone
        )
    }

    // Function to get the clinic wallet balance.
    public fun get_clinic_wallet_balance(clinic: &Clinic) : &Balance<SUI> {
        &clinic.wallet
    }

    // Function to get the patient wallet balance.
    public fun get_patient_wallet_balance(patient: &Patient) : &Balance<SUI> {
        &patient.wallet
    }

    // Function to enable the Patient to add coin to the wallet
    public fun add_coin_to_patient_wallet(
        patient: &mut Patient,
        coin: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        // Verify patient is making the call
        assert!(tx_context::sender(ctx) == patient.patient_address, InvalidPatient);
        let balance_ = coin::into_balance(coin);
        balance::join(&mut patient.wallet, balance_);
    }



    // Functionality to enable  the patient to make payment
    public fun make_payment(
        patient: &mut Patient,
        clinic: &mut Clinic,
        payment: u64,
        ctx: &mut TxContext
    ) {
        // Verify patient is making the call
        assert!(tx_context::sender(ctx) == patient.patient_address, InvalidPatient);
        // Verify the patient has enough balance to make payment
        assert!(payment <= balance::value(&patient.wallet), InvalidAmount);
        // Transfer the payment from the patient wallet to the clinic wallet
        let coin = coin::take(&mut patient.wallet, payment, ctx);
        transfer::public_transfer(coin, clinic.clinic_address);

    }   

 

    // Get appointment for a clinic using the created_at
    public fun get_appointment_for_clinic(clinic: &Clinic, created_at: u64) : &Appointment {
        // Check for Invalid Appointment
        assert!(table::contains(&clinic.appointments, created_at), InvalidAppointment);
       let appointment = table::borrow<u64, Appointment>(&clinic.appointments, created_at);
         appointment
    }

    // Check if an appointment exists in the clinic and is paid for
    public fun check_appointment_status(clinic: &Clinic, created_at: u64) : bool {
        let appointment = table::borrow<u64, Appointment>(&clinic.appointments, created_at);
        appointment.status == string::utf8(b"Confirmed")
    }

    //  Functionality to allow Clinic to withdraw from the wallet
    public fun withdraw_funds(
        clinic: &mut Clinic,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(clinic.clinic_address == tx_context::sender(ctx), InvalidClinic);
        assert!(amount <= balance::value(&clinic.wallet), InvalidAmount);
        let withdrawal_amount = coin::take(&mut clinic.wallet, amount, ctx);
        transfer::public_transfer(withdrawal_amount, clinic.clinic_address);
    }
    
  
}
