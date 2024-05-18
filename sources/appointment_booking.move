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
    use std::vector;

    // Error codes
    const InvalidAppointment: u64 = 1;
    const AppointmentAlreadyExists: u64 = 2;
    const InvalidClinic: u64 = 3;
    const InvalidPatient: u64 = 4;
    const InvalidAmount: u64 = 5;
    const UnauthorizedAccess: u64 = 6;
    const InvalidData: u64 = 7;

    // Enum for appointment status
    enum AppointmentStatus {
        Pending,
        Confirmed,
        Cancelled,
    }

    // Structs
    struct Appointment has key, store {
        id: UID,
        patient: address,
        clinic: address,
        description: vector<u8>,
        booking_date: vector<u8>,
        booking_time: vector<u8>,
        created_at: u64,
        status: AppointmentStatus,
    }

    struct Clinic has key, store {
        id: UID,
        name: vector<u8>,
        address: vector<u8>,
        phone: vector<u8>,
        email: vector<u8>,
        clinic_address: address,
        wallet: Balance<SUI>,
        appointments: Table<u64, Appointment>,
    }

    struct Patient has key, store {
        id: UID,
        name: vector<u8>,
        patient_address: address,
        phone: vector<u8>,
        wallet: Balance<SUI>,
    }

    // Struct to manage roles
    struct Roles has key, store {
        admins: vector<address>,
        clinics: vector<address>,
        patients: vector<address>,
    }

    // Function to create a new Clinic (only admins can create)
    public fun new_clinic(
        roles: &Roles,
        name: vector<u8>,
        address: vector<u8>,
        phone: vector<u8>,
        email: vector<u8>,
        clinic_address: address,
        ctx: &mut TxContext
    ): Clinic {
        // Check if the sender is an admin
        assert!(vector::contains(&roles.admins, tx_context::sender(ctx)), UnauthorizedAccess);

        // Validate input data
        validate_string(name);
        validate_string(address);
        validate_string(phone);
        validate_string(email);

        let clinic = Clinic {
            id: object::new(ctx),
            name,
            address,
            phone,
            email,
            clinic_address,
            wallet: balance::zero(),
            appointments: table::new<u64, Appointment>(ctx),
        };
        clinic
    }

    // Function to create a new Patient
    public fun new_patient(
        roles: &Roles,
        name: vector<u8>,
        address: address,
        phone: vector<u8>,
        ctx: &mut TxContext
    ): Patient {
        // Check if the sender is an admin
        assert!(vector::contains(&roles.admins, tx_context::sender(ctx)), UnauthorizedAccess);

        // Validate input data
        validate_string(name);
        validate_string(phone);

        let patient = Patient {
            id: object::new(ctx),
            name,
            patient_address: address,
            phone,
            wallet: balance::zero(),
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
        assert!(patient.patient_address != clinic.clinic_address, InvalidPatient);
        assert!(clinic.clinic_address != patient.patient_address, InvalidClinic);
        assert!(!table::contains(&clinic.appointments, created_at), AppointmentAlreadyExists);

        // Validate input data
        validate_string(description);
        validate_string(booking_date);
        validate_string(booking_time);

        let appointment = Appointment {
            id: object::new(ctx),
            patient: patient.patient_address,
            clinic: clinic.clinic_address,
            description,
            booking_date,
            booking_time,
            created_at,
            status: AppointmentStatus::Pending,
        };

        table::add<u64, Appointment>(&mut clinic.appointments, created_at, appointment);

        // Logging (optional)
        // log::info(&format!("New appointment created with ID: {}", appointment.id));
    }

    // Function to get appointment details
    public fun get_appointment_details(appointment: &Appointment): (vector<u8>, vector<u8>, vector<u8>, u64, AppointmentStatus) {
        (
            appointment.description,
            appointment.booking_date,
            appointment.booking_time,
            appointment.created_at,
            appointment.status
        )
    }

    // Function to get clinic details
    public fun get_clinic_details(clinic: &Clinic): (vector<u8>, vector<u8>, vector<u8>, vector<u8>, address) {
        (
            clinic.name,
            clinic.address,
            clinic.phone,
            clinic.email,
            clinic.clinic_address
        )
    }

    // Function to get patient details
    public fun get_patient_details(patient: &Patient): (vector<u8>, address, vector<u8>) {
        (
            patient.name,
            patient.patient_address,
            patient.phone
        )
    }

    // Function to get clinic wallet balance
    public fun get_clinic_wallet_balance(clinic: &Clinic): &Balance<SUI> {
        &clinic.wallet
    }

    // Function to get patient wallet balance
    public fun get_patient_wallet_balance(patient: &Patient): &Balance<SUI> {
        &patient.wallet
    }

    // Function to add coin to patient wallet
    public fun add_coin_to_patient_wallet(
        patient: &mut Patient,
        coin: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == patient.patient_address, InvalidPatient);
        let balance_ = coin::into_balance(coin);
        balance::join(&mut patient.wallet, balance_);
    }

    // Function for patient to make payment to clinic
    public fun make_payment(
        patient: &mut Patient,
        clinic: &mut Clinic,
        created_at: u64,
        payment: u64,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == patient.patient_address, InvalidPatient);
        assert!(payment <= balance::value(&patient.wallet), InvalidAmount);
        let coin = coin::take(&mut patient.wallet, payment, ctx);
        transfer::public_transfer(coin, clinic.clinic_address);

        // Update the appointment status to "Confirmed"
        let appointment = table::borrow_mut<u64, Appointment>(&mut clinic.appointments, created_at);
        appointment.status = AppointmentStatus::Confirmed;

        // Logging (optional)
        // log::info(&format!("Payment made for appointment ID: {}. Status updated to Confirmed", created_at));
    }

    // Function for clinic to withdraw funds
    public fun withdraw_funds(
        clinic: &mut Clinic,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(clinic.clinic_address == tx_context::sender(ctx), InvalidClinic);
        assert!(amount <= balance::value(&clinic.wallet), InvalidAmount);
        let withdrawal_amount = coin::take(&mut clinic.wallet, amount, ctx);
        transfer::public_transfer(withdrawal_amount, clinic.clinic_address);

        // Logging (optional)
        // log::info(&format!("Clinic ID: {} withdrew {} SUI", clinic.id, amount));
    }

    // Function to cancel an appointment
    public fun cancel_appointment(
        clinic: &mut Clinic,
        created_at: u64,
        ctx: &mut TxContext
    ) {
        assert!(clinic.clinic_address == tx_context::sender(ctx), UnauthorizedAccess);
        let appointment = table::borrow_mut<u64, Appointment>(&mut clinic.appointments, created_at);
        appointment.status = AppointmentStatus::Cancelled;

        // Logging (optional)
        // log::info(&format!("Appointment ID: {} cancelled", created_at));
    }

    // Function to list appointments for a clinic
    public fun list_appointments_for_clinic(clinic: &Clinic): vector<Appointment> {
        let mut appointments: vector<Appointment> = vector::empty();
        let keys = table::keys<u64, Appointment>(&clinic.appointments);
        for key in keys {
            let appointment = table::borrow<u64, Appointment>(&clinic.appointments, key);
            vector::push_back(&mut appointments, appointment);
        }
        appointments
    }

    // Function to list appointments for a patient
    public fun list_appointments_for_patient(patient: &Patient, clinic: &Clinic): vector<Appointment> {
        let mut appointments: vector<Appointment> = vector::empty();
        let keys = table::keys<u64, Appointment>(&clinic.appointments);
        for key in keys {
            let appointment = table::borrow<u64, Appointment>(&clinic.appointments, key);
            if appointment.patient == patient.patient_address {
                vector::push_back(&mut appointments, appointment);
            }
        }
        appointments
    }

    // Helper function to validate string input
    fun validate_string(input: vector<u8>) {
        assert!(vector::length(&input) > 0, InvalidData);
        assert!(vector::length(&input) <= 255, InvalidData); // Example limit
    }

    // Initialize roles (should be called once by an admin)
    public fun initialize_roles(admins: vector<address>, ctx: &mut TxContext): Roles {
        Roles {
            admins,
            clinics: vector::empty(),
            patients: vector::empty(),
        }
    }

    // Add a new admin
    public fun add_admin(roles: &mut Roles, new_admin: address, ctx: &mut TxContext) {
        assert!(vector::contains(&roles.admins, tx_context::sender(ctx)), UnauthorizedAccess);
        vector::push_back(&mut roles.admins, new_admin);
    }

    // Add a new clinic role
    public fun add_clinic(roles: &mut Roles, new_clinic: address, ctx: &mut TxContext) {
        assert!(vector::contains(&roles.admins, tx_context::sender(ctx)), UnauthorizedAccess);
        vector::push_back(&mut roles.clinics, new_clinic);
    }

    // Add a new patient role
    public fun add_patient(roles: &mut Roles, new_patient: address, ctx: &mut TxContext) {
        assert!(vector::contains(&roles.admins, tx_context::sender(ctx)), UnauthorizedAccess);
        vector::push_back(&mut roles.patients, new_patient);
    }
}
