import Foundation

@objc(TierletServiceProtocol)
protocol TierletServiceProtocol {
    func ping(withReply reply: @escaping (String) -> Void)
    func status(withReply reply: @escaping (TierletServiceStatus) -> Void)
}
