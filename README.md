# Appointment Booking Module
## Overview

The `appointment_booking`  is designed to facilitate the scheduling and management of appointments between patients and clinics. This  includes functionalities for creating and managing clinics, patients, and appointments, as well as handling financial transactions related to appointment bookings.

## Functions
## Creating Entities
### new_clinic

``` move
    public fun new_clinic(
    name: vector<u8>,
    address: vector<u8>,
    phone: vector<u8>,
    email: vector<u8>,
    clinic_address: address,
    ctx: &mut TxContext
) : Clinic

```

Creates a new Clinic object.
### new_patient

``` move 
public fun new_patient(
    name: vector<u8>,
    address: address,
    phone: vector<u8>,
    ctx: &mut TxContext
) : Patient

```
 Creates a new Patient object.
## Managing Appointments
### new_appointment

``` bash
public fun new_appointment(
    patient: &mut Patient,
    clinic: &mut Clinic,
    description: vector<u8>,
    booking_date: vector<u8>,
    booking_time: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext
)
```
Creates a new Appointment for a patient at a clinic.
### get_appointment_for_clinic

``` move 
public fun get_appointment_for_clinic(clinic: &Clinic, created_at: u64) : &Appointment
 ```

 Retrieves an appointment by its creation timestamp.
### check_appointment_status

``` move 
public fun check_appointment_status(clinic: &Clinic, created_at: u64) : bool
```

Checks if an appointment exists and if it has been paid for.
## Financial Transactions
### add_coin_to_patient_wallet

``` move 
public fun add_coin_to_patient_wallet(
    patient: &mut Patient,
    coin: Coin<SUI>,
    ctx: &mut TxContext
)
```
Adds SUI coins to a patient's wallet.
### make_payment

``` move 
public fun make_payment(
    patient: &mut Patient,
    clinic: &mut Clinic,
    payment: u64,
    ctx: &mut TxContext
)
```
Transfers payment from a patient's wallet to a clinic's wallet.
### withdraw_funds

``` move 
public fun withdraw_funds(
    clinic: &mut Clinic,
    amount: u64,
    ctx: &mut TxContext
)

```

Allows a clinic to withdraw funds from its wallet.
## Utility Functions
### get_appointment_details

``` move 
public fun get_appointment_details(appointment: &Appointment) : (vector<u8>, vector<u8>, vector<u8>, u64, String)
```

Retrieves details of an appointment.
### get_clinic_details

``` move 
public fun get_clinic_details(clinic: &Clinic) : (vector<u8>, vector<u8>, vector<u8>, vector<u8>, address)

```

Retrieves details of a clinic.
### get_patient_details

``` move 
public fun get_patient_details(patient: &Patient) : (vector<u8>, address, vector<u8>)
```
Retrieves details of a patient.
### get_clinic_wallet_balance

``` move 
public fun get_clinic_wallet_balance(clinic: &Clinic) : &Balance<SUI>
```
Retrieves the wallet balance of a clinic.
### get_patient_wallet_balance
``` move 
public fun get_patient_wallet_balance(patient: &Patient) : &Balance<SUI>
```
Retrieves the wallet balance of a patient.

## Conclusion

The appointment_booking module provides a comprehensive solution for managing clinic appointments, including creating entities, handling bookings, and processing payments. The module ensures that only valid transactions occur by enforcing various checks and balances through its error handling constants and assertions.
