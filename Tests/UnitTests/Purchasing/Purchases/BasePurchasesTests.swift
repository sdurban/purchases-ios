//
//  Copyright RevenueCat Inc. All Rights Reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      https://opensource.org/licenses/MIT
//
//  BasePurchasesTests.swift
//
//  Created by Nacho Soto on 5/25/22.

import Nimble
import StoreKit
import XCTest

@testable import RevenueCat

class BasePurchasesTests: TestCase {

    private static let userDefaultsSuiteName = "TestDefaults"

    override func setUpWithError() throws {
        try super.setUpWithError()

        self.userDefaults = UserDefaults(suiteName: Self.userDefaultsSuiteName)
        self.systemInfo = MockSystemInfo(finishTransactions: true)
        self.deviceCache = MockDeviceCache(systemInfo: self.systemInfo, userDefaults: self.userDefaults)
        self.requestFetcher = MockRequestFetcher()
        self.mockProductsManager = MockProductsManager(systemInfo: self.systemInfo,
                                                       requestTimeout: Configuration.storeKitRequestTimeoutDefault)
        self.mockOperationDispatcher = MockOperationDispatcher()
        self.mockReceiptParser = MockReceiptParser()
        self.identityManager = MockIdentityManager(mockAppUserID: Self.appUserID)
        self.mockIntroEligibilityCalculator = MockIntroEligibilityCalculator(productsManager: self.mockProductsManager,
                                                                             receiptParser: self.mockReceiptParser)
        let platformInfo = Purchases.PlatformInfo(flavor: "iOS", version: "4.4.0")
        let systemInfoAttribution = try MockSystemInfo(platformInfo: platformInfo,
                                                       finishTransactions: true)
        self.receiptFetcher = MockReceiptFetcher(requestFetcher: self.requestFetcher, systemInfo: systemInfoAttribution)
        self.attributionFetcher = MockAttributionFetcher(attributionFactory: MockAttributionTypeFactory(),
                                                         systemInfo: systemInfoAttribution)
        self.backend = MockBackend(httpClient: MockHTTPClient(systemInfo: self.systemInfo,
                                                              eTagManager: MockETagManager()),
                                   apiKey: "mockAPIKey",
                                   attributionFetcher: self.attributionFetcher)
        self.subscriberAttributesManager = MockSubscriberAttributesManager(
            backend: self.backend,
            deviceCache: self.deviceCache,
            operationDispatcher: self.mockOperationDispatcher,
            attributionFetcher: self.attributionFetcher,
            attributionDataMigrator: AttributionDataMigrator()
        )
        self.attributionPoster = AttributionPoster(deviceCache: self.deviceCache,
                                                   currentUserProvider: self.identityManager,
                                                   backend: self.backend,
                                                   attributionFetcher: self.attributionFetcher,
                                                   subscriberAttributesManager: self.subscriberAttributesManager)
        self.customerInfoManager = CustomerInfoManager(operationDispatcher: self.mockOperationDispatcher,
                                                       deviceCache: self.deviceCache,
                                                       backend: self.backend,
                                                       systemInfo: self.systemInfo)
        self.mockOfferingsManager = MockOfferingsManager(deviceCache: self.deviceCache,
                                                         operationDispatcher: self.mockOperationDispatcher,
                                                         systemInfo: self.systemInfo,
                                                         backend: self.backend,
                                                         offeringsFactory: self.offeringsFactory,
                                                         productsManager: self.mockProductsManager)
        self.mockManageSubsHelper = MockManageSubscriptionsHelper(systemInfo: self.systemInfo,
                                                                  customerInfoManager: self.customerInfoManager,
                                                                  currentUserProvider: self.identityManager)
        self.mockBeginRefundRequestHelper = MockBeginRefundRequestHelper(systemInfo: self.systemInfo,
                                                                         customerInfoManager: self.customerInfoManager,
                                                                         currentUserProvider: self.identityManager)
        self.mockTransactionsManager = MockTransactionsManager(storeKit2Setting: self.systemInfo.storeKit2Setting,
                                                               receiptParser: self.mockReceiptParser)
    }

    override func tearDown() {
        self.deviceCache = nil
        self.purchases = nil

        Purchases.clearSingleton()

        UserDefaults.standard.removePersistentDomain(forName: Self.userDefaultsSuiteName)

        super.tearDown()
    }

    var receiptFetcher: MockReceiptFetcher!
    var requestFetcher: MockRequestFetcher!
    var mockProductsManager: MockProductsManager!
    var backend: MockBackend!
    let storeKitWrapper = MockStoreKitWrapper()
    let notificationCenter = MockNotificationCenter()
    var userDefaults: UserDefaults! = nil
    let offeringsFactory = MockOfferingsFactory()
    var deviceCache: MockDeviceCache!
    var subscriberAttributesManager: MockSubscriberAttributesManager!
    var identityManager: MockIdentityManager!
    var systemInfo: MockSystemInfo!
    var mockOperationDispatcher: MockOperationDispatcher!
    var mockIntroEligibilityCalculator: MockIntroEligibilityCalculator!
    var mockReceiptParser: MockReceiptParser!
    var mockTransactionsManager: MockTransactionsManager!
    var attributionFetcher: MockAttributionFetcher!
    var attributionPoster: AttributionPoster!
    var customerInfoManager: CustomerInfoManager!
    var mockOfferingsManager: MockOfferingsManager!
    var purchasesOrchestrator: PurchasesOrchestrator!
    var trialOrIntroPriceEligibilityChecker: MockTrialOrIntroPriceEligibilityChecker!
    var mockManageSubsHelper: MockManageSubscriptionsHelper!
    var mockBeginRefundRequestHelper: MockBeginRefundRequestHelper!

    // swiftlint:disable:next weak_delegate
    var purchasesDelegate = MockPurchasesDelegate()

    var purchases: Purchases!

    func setupPurchases(automaticCollection: Bool = false) {
        Purchases.automaticAppleSearchAdsAttributionCollection = automaticCollection
        self.identityManager.mockIsAnonymous = false

        self.initializePurchasesInstance(appUserId: self.identityManager.currentAppUserID)
    }

    func setupAnonPurchases() {
        Purchases.automaticAppleSearchAdsAttributionCollection = false
        self.identityManager.mockIsAnonymous = true
        self.initializePurchasesInstance(appUserId: nil)
    }

    func setupPurchasesObserverModeOn() throws {
        self.systemInfo = try MockSystemInfo(platformInfo: nil, finishTransactions: false)
        self.initializePurchasesInstance(appUserId: nil)
    }

    func initializePurchasesInstance(appUserId: String?) {
        self.purchasesOrchestrator = PurchasesOrchestrator(
            productsManager: self.mockProductsManager,
            storeKitWrapper: self.storeKitWrapper,
            systemInfo: self.systemInfo,
            subscriberAttributesManager: self.subscriberAttributesManager,
            operationDispatcher: self.mockOperationDispatcher,
            receiptFetcher: self.receiptFetcher,
            customerInfoManager: self.customerInfoManager,
            backend: self.backend,
            currentUserProvider: self.identityManager,
            transactionsManager: self.mockTransactionsManager,
            deviceCache: self.deviceCache,
            manageSubscriptionsHelper: self.mockManageSubsHelper,
            beginRefundRequestHelper: self.mockBeginRefundRequestHelper
        )
        self.trialOrIntroPriceEligibilityChecker = MockTrialOrIntroPriceEligibilityChecker(
            systemInfo: self.systemInfo,
            receiptFetcher: self.receiptFetcher,
            introEligibilityCalculator: self.mockIntroEligibilityCalculator,
            backend: self.backend,
            currentUserProvider: self.identityManager,
            operationDispatcher: self.mockOperationDispatcher,
            productsManager: self.mockProductsManager
        )
        self.purchases = Purchases(appUserID: appUserId,
                                   requestFetcher: self.requestFetcher,
                                   receiptFetcher: self.receiptFetcher,
                                   attributionFetcher: self.attributionFetcher,
                                   attributionPoster: self.attributionPoster,
                                   backend: self.backend,
                                   storeKitWrapper: self.storeKitWrapper,
                                   notificationCenter: self.notificationCenter,
                                   systemInfo: self.systemInfo,
                                   offeringsFactory: self.offeringsFactory,
                                   deviceCache: self.deviceCache,
                                   identityManager: self.identityManager,
                                   subscriberAttributesManager: self.subscriberAttributesManager,
                                   operationDispatcher: self.mockOperationDispatcher,
                                   customerInfoManager: self.customerInfoManager,
                                   productsManager: self.mockProductsManager,
                                   offeringsManager: self.mockOfferingsManager,
                                   purchasesOrchestrator: self.purchasesOrchestrator,
                                   trialOrIntroPriceEligibilityChecker: self.trialOrIntroPriceEligibilityChecker)

        self.purchasesOrchestrator.delegate = self.purchases
        self.purchases.delegate = self.purchasesDelegate

        Purchases.setDefaultInstance(self.purchases)
    }

}

extension BasePurchasesTests {

    static let appUserID = "app_user_id"

    static let emptyCustomerInfoData: [String: Any] = [
        "request_date": "2019-08-16T10:30:42Z",
        "subscriber": [
            "first_seen": "2019-07-17T00:05:54Z",
            "original_app_user_id": BasePurchasesTests.appUserID,
            "subscriptions": [:],
            "other_purchases": [:],
            "original_application_version": NSNull()
        ]
    ]

}

extension BasePurchasesTests {

    final class MockBackend: Backend {
        var userID: String?
        var originalApplicationVersion: String?
        var originalPurchaseDate: Date?
        var getSubscriberCallCount = 0
        var overrideCustomerInfoResult: Result<CustomerInfo, BackendError> = .success(
            // swiftlint:disable:next force_try
            try! CustomerInfo(data: BasePurchasesTests.emptyCustomerInfoData)
        )

        override func getCustomerInfo(appUserID: String, completion: @escaping Backend.CustomerInfoResponseHandler) {
            self.getSubscriberCallCount += 1
            self.userID = appUserID

            let result = self.overrideCustomerInfoResult
            DispatchQueue.main.async {
                completion(result)
            }
        }

        var postReceiptDataCalled = false
        var postedReceiptData: Data?
        var postedIsRestore: Bool?
        var postedProductID: String?
        var postedPrice: Decimal?
        var postedPaymentMode: StoreProductDiscount.PaymentMode?
        var postedIntroPrice: Decimal?
        var postedCurrencyCode: String?
        var postedSubscriptionGroup: String?
        var postedDiscounts: [StoreProductDiscount]?
        var postedOfferingIdentifier: String?
        var postedObserverMode: Bool?

        var postReceiptResult: Result<CustomerInfo, BackendError>?
        var aliasError: BackendError?
        var aliasCalled = false

        override func post(receiptData: Data,
                           appUserID: String,
                           isRestore: Bool,
                           productData: ProductRequestData?,
                           presentedOfferingIdentifier: String?,
                           observerMode: Bool,
                           subscriberAttributes: [String: SubscriberAttribute]?,
                           completion: @escaping Backend.CustomerInfoResponseHandler) {
            self.postReceiptDataCalled = true
            self.postedReceiptData = receiptData
            self.postedIsRestore = isRestore

            if let productData = productData {
                self.postedProductID = productData.productIdentifier
                self.postedPrice = productData.price

                self.postedPaymentMode = productData.paymentMode
                self.postedIntroPrice = productData.introPrice
                self.postedSubscriptionGroup = productData.subscriptionGroup

                self.postedCurrencyCode = productData.currencyCode
                self.postedDiscounts = productData.discounts
            }

            self.postedOfferingIdentifier = presentedOfferingIdentifier
            self.postedObserverMode = observerMode
            completion(self.postReceiptResult ?? .failure(.missingAppUserID()))
        }

        var postedProductIdentifiers: [String]?

        override func getIntroEligibility(appUserID: String,
                                          receiptData: Data,
                                          productIdentifiers: [String],
                                          completion: @escaping IntroEligibilityResponseHandler) {
            self.postedProductIdentifiers = productIdentifiers

            var eligibilities = [String: IntroEligibility]()
            for productID in productIdentifiers {
                eligibilities[productID] = IntroEligibility(eligibilityStatus: .eligible)
            }

            completion(eligibilities, nil)
        }

        var failOfferings = false
        var badOfferingsResponse = false
        var gotOfferings = 0

        override func getOfferings(appUserID: String, completion: @escaping OfferingsResponseHandler) {
            self.gotOfferings += 1
            if self.failOfferings {
                completion(.failure(.unexpectedBackendResponse(.getOfferUnexpectedResponse)))
                return
            }
            if self.badOfferingsResponse {
                completion(.failure(.networkError(.decoding(CodableError.invalidJSONObject(value: [:]), Data()))))
                return
            }

            completion(.success(.mockResponse))
        }

        override func createAlias(appUserID: String, newAppUserID: String, completion: ((BackendError?) -> Void)?) {
            self.aliasCalled = true
            if self.aliasError != nil {
                completion!(self.aliasError)
            } else {
                self.userID = newAppUserID
                completion!(nil)
            }
        }

        var invokedPostAttributionData = false
        var invokedPostAttributionDataCount = 0
        // swiftlint:disable:next large_tuple
        var invokedPostAttributionDataParameters: (
            data: [String: Any]?,
            network: AttributionNetwork,
            appUserID: String?
        )?
        var invokedPostAttributionDataParametersList = [(data: [String: Any]?,
                                                         network: AttributionNetwork,
                                                         appUserID: String?)]()
        var stubbedPostAttributionDataCompletionResult: (BackendError?, Void)?

        override func post(attributionData: [String: Any],
                           network: AttributionNetwork,
                           appUserID: String,
                           completion: ((BackendError?) -> Void)? = nil) {
            self.invokedPostAttributionData = true
            self.invokedPostAttributionDataCount += 1
            self.invokedPostAttributionDataParameters = (attributionData, network, appUserID)
            self.invokedPostAttributionDataParametersList.append((attributionData, network, appUserID))
            if let result = stubbedPostAttributionDataCompletionResult {
                completion?(result.0)
            }
        }

        var postOfferForSigningCalled = false
        var postOfferForSigningPaymentDiscountResponse: Result<[String: Any], BackendError> = .success([:])

        override func post(offerIdForSigning offerIdentifier: String,
                           productIdentifier: String,
                           subscriptionGroup: String?,
                           receiptData: Data,
                           appUserID: String,
                           completion: @escaping OfferSigningResponseHandler) {
            self.postOfferForSigningCalled = true

            completion(
                self.postOfferForSigningPaymentDiscountResponse.map {
                    (
                        // swiftlint:disable:next force_cast line_length
                        $0["signature"] as! String, $0["keyIdentifier"] as! String, $0["nonce"] as! UUID, $0["timestamp"] as! Int
                    )
                }
            )
        }
    }
}

extension OfferingsResponse {

    static let mockResponse: Self = .init(
        currentOfferingId: "base",
        offerings: [
            .init(identifier: "base",
                  description: "This is the base offering",
                  packages: [
                    .init(identifier: "$rc_monthly", platformProductIdentifier: "monthly_freetrial")
                  ])
        ]
    )

}