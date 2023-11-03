// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import PassKit

protocol PKPaymentRequestConvertible {
  func convertToPKPaymentRequest() -> PKPaymentRequest
}

protocol RLApplePayCouponCodeService {
  func applyCouponCode(_ couponCode: Double) async throws -> PKPaymentRequestConvertible
}

enum RLApplePayError: Error {
  case invalidCouponCode(String)
  
  static var invalidCouponCodeError: RLApplePayError = .invalidCouponCode("Invalid coupon code")
}

final class RLApplePay: NSObject {
  typealias ApplePayStatus = (canMakePayments: Bool, canSetupCards: Bool)
  
  static let supportedNetworks: [PKPaymentNetwork] = [
    .amex,
    .discover,
    .masterCard,
    .visa
  ]
  
  private(set) var couponCodeService: RLApplePayCouponCodeService?
  private(set) var paymentRequest: PKPaymentRequest?
  
  class func applePayStatus() -> ApplePayStatus {
    return (PKPaymentAuthorizationController.canMakePayments(),
            PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks))
  }
  
  func startPayment(with orderInfo: PKPaymentRequestConvertible, couponCodeService: RLApplePayCouponCodeService? = nil) {
    self.couponCodeService = couponCodeService
    
    self.paymentRequest = orderInfo.convertToPKPaymentRequest()
    
    let paymentAuthorizationController = PKPaymentAuthorizationController(paymentRequest: self.paymentRequest!)
    paymentAuthorizationController.delegate = self
    paymentAuthorizationController.present()
  }
}

extension RLApplePay: PKPaymentAuthorizationControllerDelegate {
  func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
  }
  
  func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController,
                                      didChangeCouponCode couponCode: String) async -> PKPaymentRequestCouponCodeUpdate {
    
    guard let couponCode = Double(couponCode) else {
      return .init(errors: [RLApplePayError.invalidCouponCodeError],
                   paymentSummaryItems: self.paymentRequest!.paymentSummaryItems,
                   shippingMethods: self.paymentRequest!.shippingMethods!)
    }
    
    do {
      let orderInfoAfterApplyingCouponCode = try await couponCodeService?.applyCouponCode(couponCode)
      self.paymentRequest = orderInfoAfterApplyingCouponCode?.convertToPKPaymentRequest()
      return .init(paymentSummaryItems: self.paymentRequest!.paymentSummaryItems)
    }
    catch {
      return .init(errors: [error],
                   paymentSummaryItems: self.paymentRequest!.paymentSummaryItems,
                   shippingMethods: self.paymentRequest!.shippingMethods!)
    }
  }
}
