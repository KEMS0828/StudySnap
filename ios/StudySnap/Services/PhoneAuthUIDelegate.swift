import UIKit
import FirebaseAuth

class PhoneAuthUIDelegate: NSObject, AuthUIDelegate {
    private var presentingViewController: UIViewController?

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return nil
        }
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        presentingViewController = topViewController()
        presentingViewController?.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        presentingViewController?.dismiss(animated: flag, completion: completion)
        presentingViewController = nil
    }
}
