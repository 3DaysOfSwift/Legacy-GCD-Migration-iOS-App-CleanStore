//
//  Order.swift
//  CleanStore
//
//  Created by Raymond Law on 2/12/19.
//  Copyright © 2019 Clean Swift LLC. All rights reserved.
//

import Foundation

struct Order: Equatable, Sendable
{
  // MARK: Contact info
  var firstName: String
  var lastName: String
  var phone: String
  var email: String
  
  // MARK: Payment info
  var billingAddress: Address
  var paymentMethod: PaymentMethod
  
  // MARK: Shipping info
  var shipmentAddress: Address
  var shipmentMethod: ShipmentMethod
  
  // MARK: Misc
  var id: String?
  var date: Date
  var total: NSDecimalNumber

  /// Draft identity needs exact dates, unlike the legacy tolerance-based equality.
  /// Text controls may write the same snapshot again when they relinquish focus.
  func hasSameSnapshot(as other: Order) -> Bool
  {
    return self == other
      && date == other.date
      && paymentMethod.expirationDate == other.paymentMethod.expirationDate
  }
}

func ==(lhs: Order, rhs: Order) -> Bool
{
  return lhs.firstName == rhs.firstName
    && lhs.lastName == rhs.lastName
    && lhs.phone == rhs.phone
    && lhs.email == rhs.email
    && lhs.billingAddress == rhs.billingAddress
    && lhs.paymentMethod == rhs.paymentMethod
    && lhs.shipmentAddress == rhs.shipmentAddress
    && lhs.shipmentMethod == rhs.shipmentMethod
    && lhs.id == rhs.id
    && lhs.date.timeIntervalSince(rhs.date) < 1.0
    && lhs.total == rhs.total
}

// MARK: - Supporting models

struct Address: Sendable
{
  var street1: String
  var street2: String?
  var city: String
  var state: String
  var zip: String
}

func ==(lhs: Address, rhs: Address) -> Bool
{
  return lhs.street1 == rhs.street1
    && lhs.street2 == rhs.street2
    && lhs.city == rhs.city
    && lhs.state == rhs.state
    && lhs.zip == rhs.zip
}

struct ShipmentMethod: Sendable
{
  enum ShippingSpeed: Int, Sendable {
    case Standard = 0 // "Standard Shipping"
    case OneDay = 1 // "One-Day Shipping"
    case TwoDay = 2 // "Two-Day Shipping"
  }
  var speed: ShippingSpeed
  
  func toString() -> String
  {
    switch speed {
    case .Standard:
      return "Standard Shipping"
    case .OneDay:
      return "One-Day Shipping"
    case .TwoDay:
      return "Two-Day Shipping"
    }
  }
}

func ==(lhs: ShipmentMethod, rhs: ShipmentMethod) -> Bool
{
  return lhs.speed == rhs.speed
}

struct PaymentMethod: Sendable
{
  var creditCardNumber: String
  var expirationDate: Date
  var cvv: String
}

func ==(lhs: PaymentMethod, rhs: PaymentMethod) -> Bool
{
  return lhs.creditCardNumber == rhs.creditCardNumber
    && lhs.expirationDate.timeIntervalSince(rhs.expirationDate) < 1.0
    && lhs.cvv == rhs.cvv
}
