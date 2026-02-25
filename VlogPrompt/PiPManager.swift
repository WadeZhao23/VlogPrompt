import AVKit
import SwiftUI
import UIKit
import Combine

class PiPManager: NSObject, ObservableObject {
    @Published var isPiPActive: Bool = false
    @Published var isPiPSupported: Bool = false

    private var pipController: AVPictureInPictureController?
    private var pipVideoCallViewController: AVPictureInPictureVideoCallViewController?
    private var contentHostingController: UIHostingController<AnyView>?

    func setup<Content: View>(contentView: Content, sourceView: UIView) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isPiPSupported = false
            return
        }

        let pipVC = AVPictureInPictureVideoCallViewController()
        pipVC.preferredContentSize = CGSize(width: 240, height: 320)

        let hostingVC = UIHostingController(rootView: AnyView(contentView))
        hostingVC.view.backgroundColor = UIColor(Color.glassDark)
        hostingVC.view.frame = pipVC.view.bounds
        hostingVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pipVC.addChild(hostingVC)
        pipVC.view.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: pipVC)

        contentHostingController = hostingVC
        pipVideoCallViewController = pipVC

        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: pipVC
        )

        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        isPiPSupported = true
    }

    func updateContent<Content: View>(_ view: Content) {
        contentHostingController?.rootView = AnyView(view)
    }

    func startPiP() {
        guard isPiPSupported else { return }
        pipController?.startPictureInPicture()
    }

    func stopPiP() {
        pipController?.stopPictureInPicture()
    }

    func togglePiP() {
        isPiPActive ? stopPiP() : startPiP()
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        isPiPActive = true
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        isPiPActive = false
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("PiP failed to start: \(error.localizedDescription)")
    }
}

// MARK: - UIViewRepresentable for PiP source

struct PiPSourceUIView: UIViewRepresentable {
    let pipManager: PiPManager
    let contentView: AnyView

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            self.pipManager.setup(contentView: self.contentView, sourceView: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
