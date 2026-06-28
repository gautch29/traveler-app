import SwiftUI
import PassKit

public struct IdentifiableURL: Identifiable {
    public var id: String { url.absoluteString }
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
}

struct WalletPassView: UIViewControllerRepresentable {
    let passURL: URL
    
    func makeUIViewController(context: Context) -> UIViewController {
        guard let passData = try? Data(contentsOf: passURL),
              let pass = try? PKPass(data: passData) else {
            let vc = UIViewController()
            let label = UILabel()
            label.text = "Failed to load Apple Wallet Pass.\n(Requires valid signed .pkpass signature)"
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            vc.view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20)
            ])
            return vc
        }
        
        guard let addPassVC = PKAddPassesViewController(pass: pass) else {
            let vc = UIViewController()
            let label = UILabel()
            label.text = "Pass already added or is invalid."
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            vc.view.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
            ])
            return vc
        }
        return addPassVC
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
